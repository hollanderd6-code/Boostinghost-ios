import Foundation
import Security
import LocalAuthentication

enum KeychainStore {
    private static let service  = "com.boostinghost.app"
    private static let account  = "jwt"
    private static let biometricSavedKey = "bh.biometric_saved"

    // MARK: - JWT principal

    static func save(_ token: String) {
        let data = Data(token.utf8)
        SecItemDelete(query() as CFDictionary)
        let attrs: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    account,
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load() -> String? {
        var q = query()
        q[kSecReturnData] = true
        q[kSecMatchLimit] = kSecMatchLimitOne
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

    // MARK: - Biometric token (Face ID protected)
    //
    // Saved with .biometryCurrentSet: if the user re-enrolls Face ID, the item is
    // automatically deleted by the OS. The UserDefaults flag persists to keep the
    // button visible; loadBiometric will return nil, and the caller shows an error.

    static func saveBiometric(_ token: String) {
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else { return }
        let data = Data(token.utf8)
        SecItemDelete(biometricQuery() as CFDictionary)
        let attrs: [CFString: Any] = [
            kSecClass:              kSecClassGenericPassword,
            kSecAttrService:        service,
            kSecAttrAccount:        "jwt_biometric",
            kSecValueData:          data,
            kSecAttrAccessControl:  access,
        ]
        let addStatus = SecItemAdd(attrs as CFDictionary, nil)
        #if DEBUG
        print("[FaceID] saveBiometric: SecItemAdd status=\(addStatus) (0=success, -25299=duplicate)")
        #endif
        UserDefaults.standard.set(true, forKey: biometricSavedKey)
    }

    // The passed LAContext must already have evaluated biometrics successfully;
    // the Keychain read completes without a second prompt.
    static func loadBiometric(context: LAContext) -> String? {
        let q: [CFString: Any] = [
            kSecClass:                    kSecClassGenericPassword,
            kSecAttrService:              service,
            kSecAttrAccount:              "jwt_biometric",
            kSecReturnData:               true,
            kSecMatchLimit:               kSecMatchLimitOne,
            kSecUseAuthenticationContext: context,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteBiometric() {
        SecItemDelete(biometricQuery() as CFDictionary)
        UserDefaults.standard.removeObject(forKey: biometricSavedKey)
    }

    // True only when the device supports biometrics AND a biometric item was saved.
    static var hasBiometricItem: Bool {
        guard UserDefaults.standard.bool(forKey: biometricSavedKey) else {
            #if DEBUG
            print("[FaceID] hasBiometricItem: UserDefaults flag absent → false")
            #endif
            return false
        }
        let ctx = LAContext()
        var err: NSError?
        let can = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        #if DEBUG
        print("[FaceID] hasBiometricItem: canEvaluatePolicy=\(can), error=\(err?.localizedDescription ?? "nil"), LAError=\(err?.code ?? -9999)")
        #endif
        return can
    }

    // Biometry type available on this device (.none if unavailable or not enrolled).
    // biometryType is only populated after canEvaluatePolicy has been called.
    static var biometryType: LABiometryType {
        let ctx = LAContext()
        var err: NSError?
        ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        return ctx.biometryType
    }

    private static func biometricQuery() -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: service,
         kSecAttrAccount: "jwt_biometric"]
    }
}
