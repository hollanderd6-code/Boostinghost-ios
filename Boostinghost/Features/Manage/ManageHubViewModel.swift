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

    // Alerte diffusion — logements non prêts à la vente
    var diffusionAlertProperties: [DiffusionProperty] = []

    var agencyAll: Bool = true

    func load() async {
        loadState = .loading

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
            depositCount = deps.filter { $0.deposit?.status == "authorized" }.count
        }

        // BACKEND: propertiesUsed ignore les délégations, corrigé côté serveur plus tard
        if let used = subscription?.propertiesUsed, used > 0 {
            propertiesUsed  = used
            propertiesLimit = subscription?.propertiesLimit
        }

        if let diff = try? await diffusionTask {
            diffusionAlertProperties = diff.logements.filter { !$0.vendable }
        }

        loadState = .loaded
    }

    private func isoToday() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
