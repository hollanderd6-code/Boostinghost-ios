import Foundation
import Observation

enum AgencyContext: Equatable {
    case own
    case allAccounts
    case delegating(userId: String, name: String, email: String)
}

@MainActor
@Observable
final class AuthStore {

    enum AppState { case loading, authenticated, unauthenticated }

    private(set) var appState: AppState = .loading
    private(set) var session: Session?
    private(set) var hasBiometricToken = false

    // MARK: - Agency

    private(set) var agencyContext: AgencyContext = .own
    private(set) var delegations: [Delegation] = []
    private(set) var canActAsAgent: Bool = false
    private(set) var accountSwitchTrigger: Int = 0

    var agencyAll: Bool { agencyContext == .allAccounts }

    // MARK: - Launch

    func verifyOnLaunch() async {
        guard let token = KeychainStore.load() else {
            appState = .unauthenticated
            return
        }
        hasBiometricToken = true
        await APIClient.shared.setToken(token)

        do {
            let _: VerifyResponse = try await APIClient.shared.get(Endpoint.verify)
            session = SessionStore.load() ?? Session(token: token, isSubAccount: false,
                                                     permissions: nil, displayName: "")
            // jwt_origin present → we launched in agency mode; canActAsAgent was
            // already confirmed at the time of the original switch.
            if KeychainStore.loadOrigin() != nil { canActAsAgent = true }
            appState = .authenticated
        } catch APIError.unauthorized {
            if let origin = KeychainStore.loadOrigin() {
                // Expired agency_access token — restore origin and re-verify
                KeychainStore.save(origin)
                KeychainStore.deleteOrigin()
                agencyContext = .own
                await APIClient.shared.setToken(origin)
                do {
                    let _: VerifyResponse = try await APIClient.shared.get(Endpoint.verify)
                    session = SessionStore.load() ?? Session(token: origin, isSubAccount: false,
                                                             permissions: nil, displayName: "")
                    appState = .authenticated
                } catch APIError.unauthorized {
                    KeychainStore.delete()
                    SessionStore.clear()
                    hasBiometricToken = false
                    await APIClient.shared.setToken(nil)
                    appState = .unauthenticated
                } catch {
                    session = SessionStore.load() ?? Session(token: origin, isSubAccount: false,
                                                             permissions: nil, displayName: "")
                    appState = .authenticated
                }
            } else {
                KeychainStore.delete()
                SessionStore.clear()
                hasBiometricToken = false
                await APIClient.shared.setToken(nil)
                appState = .unauthenticated
            }
        } catch {
            // Network / 5xx / Render cold-start — don't disconnect
            session = SessionStore.load() ?? Session(token: token, isSubAccount: false,
                                                     permissions: nil, displayName: "")
            appState = .authenticated
        }
    }

    // MARK: - Sign in

    func signIn(email: String, password: String) async throws {
        let body = LoginBody(email: email, password: password)

        // 1 — try main account
        if let main: MainLoginResponse = try? await APIClient.shared.post(Endpoint.login, body: body) {
            let token = await refreshedToken(main.token)
            let displayName = main.user.name ?? main.user.email
            await finalize(Session(token: token, isSubAccount: false,
                                   permissions: nil, displayName: displayName), token: token)
            return
        }

        // 2 — try sub-account (error propagates to caller)
        let sub: SubLoginResponse = try await APIClient.shared.post(Endpoint.subLogin, body: body)
        let token = await refreshedToken(sub.token)
        await finalize(Session(token: token, isSubAccount: true,
                               permissions: sub.subAccount.permissions,
                               displayName: sub.subAccount.name), token: token)
    }

    // MARK: - Sign out

    func signOut() {
        KeychainStore.delete()
        KeychainStore.deleteOrigin()
        SessionStore.clear()
        session = nil
        hasBiometricToken = false
        agencyContext = .own
        canActAsAgent = false
        delegations = []
        appState = .unauthenticated
        Task { await APIClient.shared.setToken(nil) }
    }

    // MARK: - Agency

    func fetchDelegations() async {
        guard session?.isSubAccount == false else { return }
        // jwt_origin present → current token belongs to the managed account and
        // has no agency plan. Skip the call; canActAsAgent and delegations set
        // before the switch remain valid.
        guard KeychainStore.loadOrigin() == nil else { return }
        do {
            let r: DelegationsResponse = try await APIClient.shared.get(Endpoint.delegations)
            canActAsAgent = r.canActAsAgent
            delegations = r.iManage
        } catch {
            canActAsAgent = false
            delegations = []
        }
    }

    func switchToAllAccounts() {
        agencyContext = .allAccounts
        accountSwitchTrigger += 1
    }

    func switchToAccount(_ delegation: Delegation) async throws {
        // Preserve the own-account token as origin on the first switch.
        if KeychainStore.loadOrigin() == nil, let current = KeychainStore.load() {
            KeychainStore.saveOrigin(current)
        }
        // The switch must always be authorised with the own-account token.
        // Using the current agency token fails when the managed account does
        // not hold an Agency plan.
        let originToken = KeychainStore.loadOrigin() ?? KeychainStore.load()
        await APIClient.shared.setToken(originToken)

        let body = AgencySwitchBody(targetUserId: delegation.userId)
        let r: AgencySwitchResponse = try await APIClient.shared.post(Endpoint.agencySwitch, body: body)
        KeychainStore.save(r.token)
        await APIClient.shared.setToken(r.token)
        agencyContext = .delegating(userId: delegation.userId,
                                    name: r.managedUser.name,
                                    email: r.managedUser.email)
        accountSwitchTrigger += 1
    }

    func restoreOwnAccount() {
        if let origin = KeychainStore.loadOrigin() {
            KeychainStore.save(origin)
            KeychainStore.deleteOrigin()
            Task { await APIClient.shared.setToken(origin) }
        }
        agencyContext = .own
        accountSwitchTrigger += 1
    }

    // MARK: - Private

    // Upgrades a 7-day login token to a 90-day biometric token.
    private func refreshedToken(_ token: String) async -> String {
        await APIClient.shared.setToken(token)
        if let r: RefreshTokenResponse = try? await APIClient.shared.post(
            Endpoint.refreshFaceID, body: EmptyBody()
        ) {
            return r.token
        }
        return token
    }

    private func finalize(_ s: Session, token: String) async {
        KeychainStore.save(token)
        SessionStore.save(s)
        await APIClient.shared.setToken(token)
        session = s
        hasBiometricToken = true
        appState = .authenticated
    }
}

// MARK: - Helpers

private struct VerifyResponse: Decodable {
    init(from decoder: any Decoder) throws {}
}
