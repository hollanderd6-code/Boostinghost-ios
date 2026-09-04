import Foundation
import Observation

@Observable
@MainActor
final class TeamViewModel {

    enum LoadState { case idle, loading, loaded, failed(String) }

    var members: [SubAccount] = []
    var loadState: LoadState  = .idle

    func load() async {
        guard case .idle = loadState else { return }
        loadState = .loading

        do {
            let r: SubAccountsTeamResponse = try await APIClient.shared.get(Endpoint.subAccountsList, agencyAll: true)
            members   = r.subAccounts
            loadState = .loaded
        } catch {
            if case APIError.decoding(let underlying) = error {
                print("[DEBUG-TEAM] APIClient DECODE ERROR: \(underlying)")
            }
            loadState = .failed("Impossible de charger l'équipe.")
        }
    }

    func reload() async {
        loadState = .idle
        await load()
    }

    func update(id: Int, request: SubAccountUpdateRequest) async throws {
        try await APIClient.shared.putVoid(Endpoint.subAccount(id), body: request, agencyAll: true)
    }
}
