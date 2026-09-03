import Foundation

struct Session: Codable, Sendable {
    let token: String
    let isSubAccount: Bool
    let permissions: [String: Bool]?
    let displayName: String

    // nil permissions = main account = all allowed.
    // Empty permissions = sub-account with no rights.
    func can(_ permission: String) -> Bool {
        guard isSubAccount else { return true }
        return permissions?[permission] == true
    }

    func canAny(_ permissions: String...) -> Bool {
        permissions.contains { can($0) }
    }
}

// MARK: - Auth response models

struct LoginBody: Encodable {
    let email: String
    let password: String
}

struct MainLoginResponse: Decodable {
    let token: String
    let user: UserPayload

    struct UserPayload: Decodable {
        let name: String?
        let email: String
    }
}

struct SubLoginResponse: Decodable {
    let token: String
    let subAccount: SubAccountPayload

    struct SubAccountPayload: Decodable {
        let name: String
        let permissions: [String: Bool]?
    }
}

struct RefreshTokenResponse: Decodable {
    let token: String
}

// MARK: - Agency delegations

struct Delegation: Decodable, Identifiable, Sendable {
    let id: Int
    let userId: String
    let name: String
    let email: String
    let propertyCount: Int?
    let acceptedAt: String?
}

struct DelegationsResponse: Decodable {
    let canActAsAgent: Bool
    let iManage: [Delegation]
}

struct AgencySwitchBody: Encodable {
    let targetUserId: String
}

struct AgencySwitchResponse: Decodable {
    let success: Bool
    let token: String
    let permissions: [String: Bool]?
    let managedUser: ManagedUser

    struct ManagedUser: Decodable {
        let id: String
        let name: String
        let email: String
    }
}

// MARK: - Session persistence (non-sensitive — token lives in Keychain)

enum SessionStore {
    private static let key = "bh_session"

    static func save(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> Session? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
