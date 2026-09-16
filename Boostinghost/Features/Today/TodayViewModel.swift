import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {

    enum State { case idle, loading, loaded, subscriptionRequired, error(String) }

    private(set) var state: State = .idle
    private(set) var compteurs: TodayResponse.Compteurs? = nil
    private(set) var arrivees: [Arrivee] = []
    private(set) var departs: [Depart] = []
    private(set) var assignments: [CleaningAssignment] = []

    // getAgencyUserIds returns [userId] alone when the account has no accepted
    // delegations, so this parameter cannot broaden the scope beyond real rights.
    // Keep mutable: a "Mon compte / Tous les comptes" picker will drive it.
    var agencyAll = true

    // MARK: - Computed

    var urgentArrivees: [Arrivee] { arrivees.filter(\.isUrgent) }
    var normalArrivees: [Arrivee] { arrivees.filter { !$0.isUrgent } }

    /// Les 7 jours de la bande calendrier : J-3 → J+3
    var weekDays: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (-3...3).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: today)
        }
    }

    var allSectionsEmpty: Bool {
        urgentArrivees.isEmpty && normalArrivees.isEmpty && departs.isEmpty && assignments.isEmpty
    }

    // MARK: - Load

    func load() async {
        if case .loaded = state {} else { state = .loading }

        async let todayResult = fetchToday()
        async let cleaningResult = fetchCleaning()

        switch await todayResult {
        case .success(let r):
            compteurs = r.compteurs
            arrivees  = r.arrivees
            departs   = r.departs
            state     = .loaded
        case .failure(let e):
            if (e as? APIError) == .subscriptionRequired {
                state = .subscriptionRequired
            } else {
                print("[TodayVM] ⚠️ Erreur chargement: \(e)")
                state = .error("Impossible de charger les données")
            }
        }

        assignments = await cleaningResult
    }

    // MARK: - Private

    private func fetchToday() async -> Result<TodayResponse, Error> {
        do {
            let r: TodayResponse = try await APIClient.shared.get(
                Endpoint.todayStates, agencyAll: agencyAll
            )
            return .success(r)
        } catch {
            return .failure(error)
        }
    }

    private func fetchCleaning() async -> [CleaningAssignment] {
        async let assignmentsTask: CleaningAssignmentsResponse =
            APIClient.shared.get(Endpoint.cleaningAssignments, agencyAll: agencyAll)
        async let propertiesTask: PropertiesResponse =
            APIClient.shared.get(Endpoint.properties, agencyAll: agencyAll)

        let allAssignments = (try? await assignmentsTask)?.assignments ?? []
        let properties     = (try? await propertiesTask)?.properties   ?? []

        let cal      = Calendar(identifier: .gregorian)
        let dc       = cal.dateComponents([.year, .month, .day], from: cal.startOfDay(for: Date()))
        let todayStr = String(format: "%04d-%02d-%02d", dc.year!, dc.month!, dc.day!)

        let nameByProp = properties.reduce(into: [String: String]()) { d, p in
            d[p.id] = p.internalName ?? p.name
        }

        return allAssignments.compactMap { a -> CleaningAssignment? in
            guard let key = a.reservationKey, key.count >= 10 else { return nil }
            let suffix = String(key.suffix(10))
            guard suffix.first?.isNumber == true, suffix == todayStr else { return nil }
            var a = a
            a.resolvedPropertyName = a.propertyId.flatMap { nameByProp[$0] }
            return a
        }
    }
}

// MARK: - APIError Equatable (partiel, pour le test subscriptionRequired)

extension APIError: Equatable {
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized):         return true
        case (.subscriptionRequired, .subscriptionRequired): return true
        default:                                     return false
        }
    }
}
