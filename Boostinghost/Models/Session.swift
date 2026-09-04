import Foundation

struct Session: Codable, Sendable {
    let token: String
    let isSubAccount: Bool
    let permissions: [String: Bool]?
    let displayName: String
    // Sub-account fields — nil for main accounts.
    let subAccountId: Int?
    let role: String?
    let parentUserId: Int?

    init(token: String, isSubAccount: Bool, permissions: [String: Bool]?,
         displayName: String, subAccountId: Int? = nil, role: String? = nil,
         parentUserId: Int? = nil) {
        self.token        = token
        self.isSubAccount = isSubAccount
        self.permissions  = permissions
        self.displayName  = displayName
        self.subAccountId = subAccountId
        self.role         = role
        self.parentUserId = parentUserId
    }

    // nil permissions = main account = all allowed.
    // Empty permissions = sub-account with no rights.
    func can(_ permission: String) -> Bool {
        guard isSubAccount else { return true }
        // JSONDecoder.convertFromSnakeCase converts dict keys too: the stored
        // permissions dict uses camelCase (canViewCalendar, not can_view_calendar).
        // Normalise the input before lookup so callers can use either form.
        let key = Self.camelCase(permission)
        if permissions?[key] == true { return true }
        if let alt = Self.loginAliases[key] { return permissions?[alt] == true }
        return false
    }

    func canAny(_ permissions: String...) -> Bool {
        permissions.contains { can($0) }
    }

    // Converts snake_case to camelCase. Already-camelCase input is returned as-is.
    private static func camelCase(_ snake: String) -> String {
        let parts = snake.split(separator: "_")
        guard let first = parts.first else { return snake }
        return String(first) + parts.dropFirst().map { $0.capitalized }.joined()
    }

    // Bidirectional alias table in camelCase (matches stored dict keys).
    // can_view_reservations ↔ can_view_calendar (login alias ↔ DB column)
    // can_manage_cleaning   ↔ can_assign_cleaning
    private static let loginAliases: [String: String] = [
        "canViewReservations": "canViewCalendar",
        "canViewCalendar":     "canViewReservations",
        "canManageCleaning":   "canAssignCleaning",
        "canAssignCleaning":   "canManageCleaning",
    ]
}

// Custom Decodable: old sessions stored in UserDefaults lack the new optional fields.
extension Session {
    init(from decoder: Decoder) throws {
        let c         = try decoder.container(keyedBy: CodingKeys.self)
        token         = try  c.decode(String.self, forKey: .token)
        isSubAccount  = (try? c.decode(Bool.self,   forKey: .isSubAccount)) ?? false
        permissions   = try? c.decodeIfPresent([String: Bool].self, forKey: .permissions)
        displayName   = (try? c.decodeIfPresent(String.self, forKey: .displayName)) ?? ""
        subAccountId  = try? c.decodeIfPresent(Int.self,    forKey: .subAccountId)
        role          = try? c.decodeIfPresent(String.self, forKey: .role)
        parentUserId  = try? c.decodeIfPresent(Int.self,    forKey: .parentUserId)
    }

    private enum CodingKeys: CodingKey {
        case token, isSubAccount, permissions, displayName, subAccountId, role, parentUserId
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
        let displayName: String  // composed: firstName + lastName, fallback on email
        let permissions: [String: Bool]?
        let id: Int?
        let role: String?
        let parentUserId: Int?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            let first = (try? c.decodeIfPresent(String.self, forKey: .firstName)) ?? ""
            let last  = (try? c.decodeIfPresent(String.self, forKey: .lastName))  ?? ""
            let email = (try? c.decodeIfPresent(String.self, forKey: .email))     ?? ""
            let composed = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
            displayName  = composed.isEmpty ? email : composed

            id           = try? c.decodeIfPresent(Int.self,    forKey: .id)
            role         = try? c.decodeIfPresent(String.self, forKey: .role)
            parentUserId = try? c.decodeIfPresent(Int.self,    forKey: .parentUserId)

            // Decode permissions tolerantly: visible_kpis arrives as {} (object), not Bool.
            // Iterate with a dynamic key type and silently drop any non-Bool value.
            if let raw = try? c.nestedContainer(keyedBy: AnyStringKey.self, forKey: .permissions) {
                var dict = [String: Bool]()
                for key in raw.allKeys {
                    if let v = try? raw.decodeIfPresent(Bool.self, forKey: key) {
                        dict[key.stringValue] = v
                    }
                }
                permissions = dict
            } else {
                permissions = nil
            }
        }

        private enum CodingKeys: String, CodingKey {
            case id, role, email, firstName, lastName, permissions
            case parentUserId  // camelCase matches JSON key sent by server
        }
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
    // Server may include pending delegations; filter to accepted only via acceptedAt or status.
    let status: String?

    var isAccepted: Bool { acceptedAt != nil || status == "accepted" }
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

// Used by SubAccountPayload to iterate unknown JSON keys when decoding permissions.
private struct AnyStringKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
