import Foundation
import Observation

@Observable
@MainActor
final class ManageHubViewModel {

    enum LoadState { case idle, loading, loaded, error(String) }

    var loadState: LoadState = .idle
    var propertyCount = 0
    var groupCount = 0

    // Badges — nil tant que non chargés
    var cleaningTodayCount: Int? = nil
    var depositCount: Int? = nil
    var propertiesUsed: Int? = nil
    var propertiesLimit: Int? = nil
    var planType: String? = nil

    var isAtStarterLimit: Bool {
        guard planType?.lowercased() == "starter",
              let used  = propertiesUsed,
              let limit = propertiesLimit else { return false }
        return used >= limit
    }

    // Alerte diffusion — logements non prêts à la vente
    var diffusionAlertProperties: [DiffusionProperty] = []

    var agencyAll: Bool = true
    var isSyncing = false

    func load() async {
        if case .loaded = loadState {} else { loadState = .loading }

        // Cinq requêtes en parallèle ; properties + groups sont critiques,
        // les trois autres alimentent les badges (échec silencieux).
        // subscriptionStatus : jamais agency=all — périmètre facturation.
        async let propsTask: PropertiesResponse = APIClient.shared.get(Endpoint.properties, agencyAll: agencyAll)
        async let groupsTask: PropertyGroupsResponse = APIClient.shared.get(Endpoint.propertyGroups, agencyAll: agencyAll)
        async let cleaningTask: CleaningAssignmentsResponse = APIClient.shared.get(Endpoint.cleaningAssignments, agencyAll: agencyAll)
        async let depositsTask: [ReservationWithDeposit] = APIClient.shared.get(Endpoint.reservationsWithDeposits, agencyAll: agencyAll)
        async let subscriptionTask: SubscriptionStatus = APIClient.shared.get(Endpoint.subscriptionStatus)
        async let diffusionTask: DiffusionResponse = APIClient.shared.get(Endpoint.propertiesDiffusion, agencyAll: true)

        do {
            let (props, groups) = try await (propsTask, groupsTask)
            propertyCount = props.properties?.count ?? 0
            groupCount    = groups.groups?.count ?? 0
        } catch {
            loadState = .error("Impossible de charger les données.")
            return
        }

        // Badges — on ignore les erreurs individuelles
        let cleaning     = try? await cleaningTask
        let deposits     = try? await depositsTask
        let subscription = try? await subscriptionTask

        if let assignments = cleaning?.assignments {
            let today = isoToday()
            print("[Ménage] \(assignments.count) assignation(s) reçue(s) · filtre date = \(today)")
            for a in assignments {
                print("[Ménage]   reservation_key=\(a.reservationKey ?? "nil")  suffix10=\(a.reservationKey.map { String($0.suffix(10)) } ?? "—")")
            }
            let matched = assignments.filter { a in
                guard let key = a.reservationKey, key.count >= 10 else { return false }
                return String(key.suffix(10)) == today
            }
            print("[Ménage] → \(matched.count) checkout(s) aujourd'hui")
            cleaningTodayCount = matched.count
        } else {
            print("[Ménage] assignations nil (requête échouée ou réponse vide)")
        }

        if let deps = deposits {
            depositCount = deps.filter { $0.depositStatus == "authorized" }.count
        }

        // BACKEND: propertiesUsed ignore les délégations, corrigé côté serveur plus tard
        planType = subscription?.planType
        if let used = subscription?.propertiesUsed, used > 0 {
            propertiesUsed  = used
            propertiesLimit = subscription?.propertiesLimit
        }

        if let diff = try? await diffusionTask {
            diffusionAlertProperties = diff.logements.filter { !$0.vendable }
        }

        loadState = .loaded
    }

    // MARK: - Synchronisation des plateformes

    func sync() async -> String {
        isSyncing = true
        defer { isSyncing = false }

        // Les deux appels partent en parallèle.
        // /api/sync/ical peut mettre plus d'une minute : timeout 120 s.
        // /api/diffusion/sync-all : on capture la réponse brute pour log.
        async let icalTask: SyncIcalResponse = APIClient.shared.post(Endpoint.syncIcal, agencyAll: true, timeout: 120)
        async let diffDataTask: Data         = APIClient.shared.postData(Endpoint.syncDiffusion, agencyAll: true)

        let ical     = try? await icalTask
        let diffData = try? await diffDataTask

        #if DEBUG
        if let d = diffData {
            print("[sync-all] \(String(data: d, encoding: .utf8) ?? "(non-UTF8)")")
        } else {
            print("[sync-all] échec — pas de réponse")
        }
        #endif

        let diffCount = diffData.flatMap { try? JSONDecoder().decode(SyncDiffusionResponse.self, from: $0) }?.count

        // Recharge l'état réel pour savoir quels logements posent problème.
        let freshDiff: DiffusionResponse? = try? await APIClient.shared.get(Endpoint.propertiesDiffusion, agencyAll: true)
        Task { await load() }

        let problems = freshDiff?.logements.filter { !$0.vendable || !$0.diffuse } ?? []

        switch (ical != nil, diffData != nil) {
        case (true, true):
            if problems.isEmpty {
                let n = diffCount ?? 0
                return n > 0
                    ? "Synchronisation terminée — \(n) logement\(n == 1 ? "" : "s") mis à jour."
                    : "Synchronisation terminée — tout est à jour."
            } else {
                let noms = problems.map { $0.nom }.joined(separator: ", ")
                return "Synchronisation terminée — \(problems.count) logement\(problems.count == 1 ? "" : "s") à régler : \(noms)"
            }
        case (false, true):
            return "Diffusion synchronisée — calendriers iCal non atteints."
        case (true, false):
            return "Calendriers iCal synchronisés — diffusion non atteinte."
        case (false, false):
            return "Synchronisation échouée."
        }
    }

    private func isoToday() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
