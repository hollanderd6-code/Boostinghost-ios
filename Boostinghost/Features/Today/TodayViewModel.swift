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
        state = .loading
        arrivees = []; departs = []; assignments = []

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
        guard let r: CleaningAssignmentsResponse = try? await APIClient.shared.get(
            Endpoint.cleaningAssignments, agencyAll: agencyAll
        ) else { return [] }
        return r.assignments ?? []
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
