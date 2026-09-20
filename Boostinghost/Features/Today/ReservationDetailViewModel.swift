import Foundation
import Observation

@MainActor
@Observable
final class ReservationDetailViewModel {

    enum LoadState { case loading, loaded }

    enum HosterzzMissionState {
        case loading
        case noMission
        case missionExists(statut: String?)
    }

    let arrivee: Arrivee

    private(set) var state: LoadState = .loading
    private(set) var reservation: Reservation? = nil
    private(set) var propertySummary: PropertySummary? = nil
    private(set) var properties: [PropertySummary] = []
    private(set) var cleanerName: String? = nil
    private(set) var hosterzzMissionState: HosterzzMissionState = .loading
    private(set) var didDelete   = false
    private(set) var deleteError: String? = nil
    private(set) var invoiceCount: Int = 0
    private(set) var invoiceCountLoaded: Bool = false

    init(arrivee: Arrivee) {
        self.arrivee = arrivee
    }

    // MARK: - Load

    func load() async {
        if case .loaded = state {} else { state = .loading; hosterzzMissionState = .loading }

        async let responseResult    = fetchReservationsResponse()
        async let assignmentsResult = fetchAssignments()
        async let hosterzzResult    = fetchHosterzzMission()
        async let invoiceResult     = fetchInvoiceCount(reservationUid: arrivee.reservationUid)

        let response      = await responseResult
        let assignments   = await assignmentsResult
        let hosterzzCheck = await hosterzzResult

        let found = (response?.reservations ?? []).first { $0.uid == arrivee.reservationUid }
        reservation = found
        // Liste complète des logements : la feuille de modification en a
        // besoin pour proposer de déplacer la réservation.
        properties = response?.properties ?? []

        if let r = found {
            let bdSum = r.daysBreakdown.map { $0.values.reduce(0, +) }
            print("[DEBUG Prix] uid=\(r.uid ?? "-")")
            print("[DEBUG Prix] amountTotal=\(r.amountTotal.map { String($0) } ?? "nil")")
            print("[DEBUG Prix] amountRooms=\(r.amountRooms.map { String($0) } ?? "nil")")
            print("[DEBUG Prix] amountCleaning=\(r.amountCleaning.map { String($0) } ?? "nil")")
            print("[DEBUG Prix] otaCommission=\(r.otaCommission.map { String($0) } ?? "nil")")
            print("[DEBUG Prix] hostPayout=\(r.hostPayout.map { String($0) } ?? "nil")")
            print("[DEBUG Prix] daysBreakdown sum=\(bdSum.map { String($0) } ?? "nil")")
            propertySummary = response?.properties?.first { $0.id == r.propertyId }
            let key = "\(r.propertyId)_\(r.startDate)_\(r.endDate)"
            if let match = assignments.first(where: { $0.reservationKey == key }),
               let name  = match.cleanerName, !name.isEmpty {
                cleanerName = name
            }
        }

        if let m = hosterzzCheck?.mission {
            hosterzzMissionState = .missionExists(statut: m.statut)
        } else {
            hosterzzMissionState = .noMission
        }

        invoiceCount = await invoiceResult
        invoiceCountLoaded = true
        state = .loaded
    }

    func refreshInvoiceCount() async {
        invoiceCount = await fetchInvoiceCount(reservationUid: arrivee.reservationUid)
    }

    // Called by the view after a successful POST /api/hosterzz/missions.
    func hosterzzMissionCreated(statut: String?) {
        hosterzzMissionState = .missionExists(statut: statut)
    }

    func clearDeleteError() { deleteError = nil }

    // MARK: - Delete / Cancel

    func delete() async {
        guard let r = reservation else { return }
        let uid = r.uid ?? r.id
        do {
            if r.isBhGuest {
                try await APIClient.shared.postVoid(
                    Endpoint.guestCancelReservation,
                    body: GuestCancelBody(uid: uid)
                )
            } else {
                try await APIClient.shared.postVoid(
                    Endpoint.manualReservationDelete,
                    body: ManualDeleteBody(propertyId: r.propertyId, uid: uid),
                    agencyAll: true
                )
            }
            didDelete = true
        } catch {
            deleteError = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    // MARK: - Private fetch helpers

    private func fetchInvoiceCount(reservationUid: String) async -> Int {
        guard !reservationUid.isEmpty else { return 0 }
        guard let resp: InvoiceHistoryResponse = try? await APIClient.shared.get(
            Endpoint.invoiceHistory,
            extraQueryItems: [URLQueryItem(name: "reservationUid", value: reservationUid)]
        ) else { return 0 }
        return resp.invoices.filter { inv in
            guard let uid = inv.reservationUid, !uid.isEmpty else { return false }
            return uid == reservationUid
        }.count
    }

    private func fetchReservationsResponse() async -> ReservationsResponse? {
        try? await APIClient.shared.get(Endpoint.reservations, agencyAll: true)
    }

    private func fetchAssignments() async -> [CleaningAssignment] {
        guard let r: CleaningAssignmentsResponse = try? await APIClient.shared.get(
            Endpoint.cleaningAssignments, agencyAll: true
        ) else { return [] }
        return r.assignments ?? []
    }

    private func fetchHosterzzMission() async -> HosterzzMissionCheckResponse? {
        try? await APIClient.shared.get(
            Endpoint.hosterzzMission,
            extraQueryItems: [URLQueryItem(name: "reservation_id", value: arrivee.reservationUid)]
        )
    }
}

// MARK: - Corps des requêtes de suppression

private struct GuestCancelBody: Encodable {
    let uid: String
}

private struct ManualDeleteBody: Encodable {
    let propertyId: String
    let uid: String
}
