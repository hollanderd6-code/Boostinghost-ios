import Foundation
import Security

enum KeychainStore {
    private static let service  = "com.boostinghost.app"
    private static let account  = "jwt"

    static func save(_ token: String) {
        let data = Data(token.utf8)
        // Delete any existing entry first
        SecItemDelete(query() as CFDictionary)
        let attrs: [CFString: Any] = [
            kSecClass:                   kSecClassGenericPassword,
            kSecAttrService:             service,
            kSecAttrAccount:             account,
            kSecValueData:               data,
            kSecAttrAccessible:          kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load() -> String? {
        var q = query()
        q[kSecReturnData]  = true
        q[kSecMatchLimit]  = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        SecItemDelete(query() as CFDictionary)
    }

    private static func query() -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: service,
         kSecAttrAccount: account]
    }

    // MARK: - Origin token (preserved during agency_access switch)

    static func saveOrigin(_ token: String) {
        let data = Data(token.utf8)
        SecItemDelete(originQuery() as CFDictionary)
        var attrs = originQuery()
        attrs[kSecValueData] = data
        attrs[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func loadOrigin() -> String? {
        var q = originQuery()
        q[kSecReturnData] = true
        q[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteOrigin() {
        SecItemDelete(originQuery() as CFDictionary)
    }

    private static func originQuery() -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: service,
         kSecAttrAccount: "jwt_origin"]
    }
}
