import Foundation
import Observation
import LocalAuthentication

// MARK: - AgencyContext

enum AgencyContext: Equatable, Codable {
    case own
    case allAccounts
    case delegating(userId: String, name: String, email: String)

    private enum CodingKeys: String, CodingKey {
        case type, userId, name, email
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "allAccounts":
            self = .allAccounts
        case "delegating":
            self = .delegating(
                userId: try c.decode(String.self, forKey: .userId),
                name:   try c.decode(String.self, forKey: .name),
                email:  try c.decode(String.self, forKey: .email)
            )
        default:
            self = .own
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .own:
            try c.encode("own", forKey: .type)
        case .allAccounts:
            try c.encode("allAccounts", forKey: .type)
        case .delegating(let userId, let name, let email):
            try c.encode("delegating", forKey: .type)
            try c.encode(userId, forKey: .userId)
            try c.encode(name,   forKey: .name)
            try c.encode(email,  forKey: .email)
        }
    }
}

// MARK: - AuthStore

@MainActor
@Observable
final class AuthStore {

    enum AppState { case loading, authenticated, unauthenticated }

    private(set) var appState: AppState = .loading
    private(set) var session: Session?
    private(set) var hasBiometricToken = false
    private(set) var biometryType: LABiometryType = .none

    // MARK: - Agency

    private(set) var agencyContext: AgencyContext = .own
    private(set) var delegations: [Delegation] = []
    private(set) var canActAsAgent: Bool = false
    private(set) var accountSwitchTrigger: Int = 0

    var agencyAll: Bool { agencyContext == .allAccounts }

    // MARK: - Launch

    func verifyOnLaunch() async {
        hasBiometricToken = KeychainStore.hasBiometricItem
        biometryType = KeychainStore.biometryType
        #if DEBUG
        print("[FaceID] verifyOnLaunch: hasBiometricToken=\(hasBiometricToken), biometryType=\(biometryType)")
        #endif
        guard let token = KeychainStore.load() else {
            appState = .unauthenticated
            return
        }
        await APIClient.shared.setToken(token)

        do {
            let verify: VerifyResponse = try await APIClient.shared.get(Endpoint.verify)
            session = hydrated(SessionStore.load() ?? Session(token: token, isSubAccount: false,
                                                              permissions: nil, displayName: ""),
                               from: verify)
            if KeychainStore.loadOrigin() != nil { canActAsAgent = true }
            restoreAgencyContext()
            appState = .authenticated
            Task { await validateRestoredContext() }
        } catch APIError.unauthorized {
            if let origin = KeychainStore.loadOrigin() {
                KeychainStore.save(origin)
                KeychainStore.deleteOrigin()
                agencyContext = .own
                clearAgencyContext()
                await APIClient.shared.setToken(origin)
                do {
                    let verify: VerifyResponse = try await APIClient.shared.get(Endpoint.verify)
                    session = hydrated(SessionStore.load() ?? Session(token: origin, isSubAccount: false,
                                                                      permissions: nil, displayName: ""),
                                       from: verify)
                    appState = .authenticated
                } catch APIError.unauthorized {
                    KeychainStore.delete()
                    SessionStore.clear()
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
                await APIClient.shared.setToken(nil)
                appState = .unauthenticated
            }
        } catch {
            // Network / 5xx / Render cold-start — don't disconnect.
            session = SessionStore.load() ?? Session(token: token, isSubAccount: false,
                                                     permissions: nil, displayName: "")
            restoreAgencyContext()
            appState = .authenticated
        }
    }

    // MARK: - Sign in (email + password)

    func signIn(email: String, password: String) async throws {
        let body = LoginBody(email: email, password: password)

        if let main: MainLoginResponse = try? await APIClient.shared.post(Endpoint.login, body: body) {
            let token = await refreshedToken(main.token)
            let displayName = main.user.name ?? main.user.email
            await finalize(Session(token: token, isSubAccount: false,
                                   permissions: nil, displayName: displayName), token: token)
            return
        }

        let sub: SubLoginResponse = try await APIClient.shared.post(Endpoint.subLogin, body: body)
        let token = await refreshedToken(sub.token)
        await finalize(Session(token: token, isSubAccount: true,
                               permissions: sub.subAccount.permissions,
                               displayName: sub.subAccount.displayName,
                               subAccountId: sub.subAccount.id,
                               role: sub.subAccount.role,
                               parentUserId: sub.subAccount.parentUserId), token: token)
    }

    // MARK: - Sign in (social — Google / Apple)

    func signInWithSocial(provider: String, idToken: String, name: String?) async throws {
        struct Body: Encodable { let provider: String; let idToken: String; let name: String? }
        let r: SocialLoginResponse = try await APIClient.shared.post(
            Endpoint.socialLogin, body: Body(provider: provider, idToken: idToken, name: name)
        )
        let token = await refreshedToken(r.token)
        let displayName = [r.user.firstName, r.user.lastName]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        await finalize(
            Session(token: token, isSubAccount: false, permissions: nil,
                    displayName: displayName.isEmpty ? r.user.email : displayName),
            token: token
        )
    }

    // MARK: - Biometric sign-in (Face ID / Touch ID)

    func signInWithBiometrics(context: LAContext) async throws {
        guard let token = KeychainStore.loadBiometric(context: context) else {
            // Biometric item missing — biometrics re-enrolled or never set.
            hasBiometricToken = false
            throw APIError.unauthorized
        }
        await APIClient.shared.setToken(token)
        do {
            let verify: VerifyResponse = try await APIClient.shared.get(Endpoint.verify)
            session = hydrated(
                SessionStore.load() ?? Session(token: token, isSubAccount: false, permissions: nil, displayName: ""),
                from: verify
            )
            restoreAgencyContext()
            appState = .authenticated
        } catch APIError.unauthorized {
            KeychainStore.delete()
            KeychainStore.deleteBiometric()
            SessionStore.clear()
            hasBiometricToken = false
            await APIClient.shared.setToken(nil)
            appState = .unauthenticated
            throw APIError.unauthorized
        } catch {
            // Network / 5xx — use cached session, same pattern as verifyOnLaunch.
            session = SessionStore.load() ?? Session(token: token, isSubAccount: false, permissions: nil, displayName: "")
            restoreAgencyContext()
            appState = .authenticated
        }
    }

    // MARK: - Sign out

    func signOut() {
        OnboardingCoordinator.shared.reset()
        KeychainStore.delete()
        KeychainStore.deleteOrigin()
        SessionStore.clear()
        clearAgencyContext()
        session = nil
        agencyContext = .own
        canActAsAgent = false
        delegations = []
        // hasBiometricToken stays true — biometric item is preserved so Face ID
        // can be offered on the next login screen without requiring password re-entry.
        appState = .unauthenticated
        Task { await APIClient.shared.setToken(nil) }
    }

    // MARK: - Agency

    func fetchDelegations() async {
        guard session?.isSubAccount == false else { return }
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
        saveAgencyContext()
        accountSwitchTrigger += 1
    }

    func switchToAccount(_ delegation: Delegation) async throws {
        if KeychainStore.loadOrigin() == nil, let current = KeychainStore.load() {
            KeychainStore.saveOrigin(current)
        }
        let originToken = KeychainStore.loadOrigin() ?? KeychainStore.load()
        await APIClient.shared.setToken(originToken)

        let body = AgencySwitchBody(targetUserId: delegation.userId)
        let r: AgencySwitchResponse = try await APIClient.shared.post(Endpoint.agencySwitch, body: body)
        KeychainStore.save(r.token)
        await APIClient.shared.setToken(r.token)
        agencyContext = .delegating(userId: delegation.userId,
                                    name: r.managedUser.name,
                                    email: r.managedUser.email)
        saveAgencyContext()
        accountSwitchTrigger += 1
    }

    func restoreOwnAccount() {
        if let origin = KeychainStore.loadOrigin() {
            KeychainStore.save(origin)
            KeychainStore.deleteOrigin()
            Task { await APIClient.shared.setToken(origin) }
        }
        agencyContext = .own
        saveAgencyContext()
        accountSwitchTrigger += 1
    }

    // MARK: - Private — context persistence

    private static let agencyContextKey = "agency.context"

    private func saveAgencyContext() {
        guard let data = try? JSONEncoder().encode(agencyContext) else { return }
        UserDefaults.standard.set(data, forKey: Self.agencyContextKey)
    }

    private func clearAgencyContext() {
        UserDefaults.standard.removeObject(forKey: Self.agencyContextKey)
    }

    private func loadSavedAgencyContext() -> AgencyContext? {
        guard let data = UserDefaults.standard.data(forKey: Self.agencyContextKey),
              let ctx  = try? JSONDecoder().decode(AgencyContext.self, from: data) else { return nil }
        return ctx
    }

    private func restoreAgencyContext() {
        guard let saved = loadSavedAgencyContext() else { return }
        switch saved {
        case .own:
            agencyContext = .own
        case .allAccounts:
            agencyContext = .allAccounts
        case .delegating(let userId, let name, let email):
            if KeychainStore.loadOrigin() != nil {
                agencyContext = .delegating(userId: userId, name: name, email: email)
            } else {
                agencyContext = .own
                clearAgencyContext()
            }
        }
    }

    private func validateRestoredContext() async {
        switch agencyContext {
        case .own:
            return
        case .allAccounts:
            await fetchDelegations()
            if delegations.isEmpty {
                agencyContext = .own
                saveAgencyContext()
                accountSwitchTrigger += 1
            }
        case .delegating:
            break
        }
    }

    // MARK: - Private

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
        #if DEBUG
        print("[FaceID] finalize: saving token + biometric token")
        #endif
        KeychainStore.save(token)
        KeychainStore.saveBiometric(token)
        SessionStore.save(s)
        await APIClient.shared.setToken(token)
        session = s
        hasBiometricToken = true
        appState = .authenticated
    }

    private func hydrated(_ s: Session, from verify: VerifyResponse) -> Session {
        guard s.displayName.isEmpty, !s.isSubAccount,
              let name = verify.displayName else { return s }
        let updated = Session(token: s.token, isSubAccount: s.isSubAccount,
                              permissions: s.permissions, displayName: name,
                              subAccountId: s.subAccountId, role: s.role,
                              parentUserId: s.parentUserId)
        SessionStore.save(updated)
        return updated
    }
}

// MARK: - Private response types

private struct SocialLoginResponse: Decodable {
    let token: String
    let user: UserPayload
    struct UserPayload: Decodable {
        let email: String
        let firstName: String?
        let lastName: String?
    }
}

private struct VerifyResponse: Decodable {
    let user: UserPayload?

    struct UserPayload: Decodable {
        let name: String?
        let email: String?
    }

    var displayName: String? {
        guard let u = user else { return nil }
        return u.name?.isEmpty == false ? u.name : u.email
    }
}
