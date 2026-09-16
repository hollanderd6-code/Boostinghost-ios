import Foundation
import Observation

@Observable
@MainActor
final class TeamViewModel {

    enum LoadState { case idle, loading, loaded, failed(String) }

    var members: [SubAccount] = []
    var loadState: LoadState  = .idle
    var showCreateSheet = false
    private(set) var targetAccounts: [TargetAccount] = []

    var isAgencyMode: Bool { targetAccounts.count > 1 }

    func load() async {
        guard case .idle = loadState else { return }
        loadState = .loading

        async let membersTask: SubAccountsTeamResponse = APIClient.shared.get(Endpoint.subAccountsList, agencyAll: true)
        async let targetsTask: TargetAccountsResponse  = APIClient.shared.get(Endpoint.targetAccounts)

        do {
            let r = try await membersTask
            members   = r.subAccounts
            loadState = .loaded
        } catch {
            if case APIError.decoding(let underlying) = error {
                print("[DEBUG-TEAM] APIClient DECODE ERROR: \(underlying)")
            }
            loadState = .failed("Impossible de charger l'équipe.")
        }
        targetAccounts = (try? await targetsTask)?.accounts ?? []
    }

    func reload() async {
        loadState = .idle
        await load()
    }

    func update(id: Int, request: SubAccountUpdateRequest) async throws {
        try await APIClient.shared.putVoid(Endpoint.subAccount(id), body: request, agencyAll: true)
    }

    // MARK: - Target accounts (GET /api/agency/target-accounts)

    func loadTargetAccounts() async {
        do {
            let r: TargetAccountsResponse = try await APIClient.shared.get(Endpoint.targetAccounts)
            targetAccounts = r.accounts
        } catch {
            targetAccounts = []
        }
    }

    // MARK: - Create (POST /api/sub-accounts/create)
    // Recharge la liste après création — la réponse partielle ne contient pas toutes les colonnes.

    func createSubAccount(email: String, password: String,
                          firstName: String, lastName: String,
                          targetUserId: String?) async throws {
        let body = SubAccountCreateBody(email: email, password: password,
                                        firstName: firstName, lastName: lastName,
                                        role: "custom", targetUserId: targetUserId)
        let _: SubAccountCreateResponse = try await APIClient.shared.post(
            Endpoint.subAccountsCreate, body: body, agencyAll: true
        )
        await reload()
    }
}
