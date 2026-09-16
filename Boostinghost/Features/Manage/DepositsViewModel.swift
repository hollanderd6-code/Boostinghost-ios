import Foundation
import Observation

@Observable
@MainActor
final class DepositsViewModel {

    enum LoadState { case idle, loading, loaded, error(String) }

    // MARK: - State

    var loadState: LoadState = .idle
    var actionError: String?        = nil
    var isActing: Bool              = false

    private var all: [ReservationWithDeposit] = []

    // MARK: - Computed categories

    /// Cautions authorized + délai de restitution dépassé → décision requise.
    var toRelease: [ReservationWithDeposit] {
        all.filter { $0.depositStatus == "authorized" && !$0.isAuthExpired && $0.isOverdue }
    }

    /// Cautions authorized + délai non encore dépassé.
    var inProgress: [ReservationWithDeposit] {
        all.filter { $0.depositStatus == "authorized" && !$0.isAuthExpired && !$0.isOverdue }
    }

    /// Autorisations Stripe expirées — aucune action possible.
    /// Ne comptent pas dans le total actif ni dans le sur-titre.
    var expired: [ReservationWithDeposit] {
        all.filter { $0.isAuthExpired }
    }

    // MARK: - Compteurs

    var activeCount: Int  { toRelease.count + inProgress.count }
    var expiredCount: Int { expired.count }

    // MARK: - Hero card

    var heroTotal: Double {
        (toRelease + inProgress).compactMap(\.depositAmount).reduce(0, +)
    }

    var heroSejourCount: Int { toRelease.count + inProgress.count }

    // MARK: - Sur-titre nav bar

    var superTitle: String {
        let n = toRelease.count
        if n == 0 { return " " }
        return n == 1 ? "1 à restituer" : "\(n) à restituer"
    }

    // MARK: - Total empreintes expirées

    var expiredTotal: Double {
        expired.compactMap(\.depositAmount).reduce(0, +)
    }

    // MARK: - Load

    func load() async {
        if case .loaded = loadState {} else { loadState = .loading }
        do {
            let resp: ReservationsWithDepositsResponse = try await APIClient.shared.get(
                Endpoint.reservationsWithDeposits,
                agencyAll: true
            )
            all = resp.reservations
            loadState = .loaded
        } catch APIError.unauthorized {
            loadState = .error("Session expirée.")
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    // MARK: - Actions

    func release(_ deposit: ReservationWithDeposit) async {
        await act(deposit: deposit, isCapture: false)
    }

    func capture(_ deposit: ReservationWithDeposit) async {
        await act(deposit: deposit, isCapture: true)
    }

    private func act(deposit: ReservationWithDeposit, isCapture: Bool) async {
        guard !deposit.depositId.isEmpty else { return }
        isActing   = true
        actionError = nil
        defer { isActing = false }
        do {
            let url = isCapture
                ? Endpoint.captureDeposit(deposit.depositId)
                : Endpoint.releaseDeposit(deposit.depositId)
            try await APIClient.shared.postVoid(url, body: EmptyBody())
            await load()
        } catch {
            actionError = error.localizedDescription
        }
    }
}
