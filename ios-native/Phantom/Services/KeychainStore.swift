import Foundation
import Security

/// Minimal Keychain wrapper for the Sign in with Apple user identifier. The
/// item is marked synchronizable so iCloud Keychain carries it to the user's
/// other devices — that's what makes "signed in on my iPad too" work without
/// a Phantom server.
enum KeychainStore {
    static let service = "com.yinanzhai.phantom.account"

    /// Returns the OSStatus of the last attempt (errSecSuccess when stored).
    @discardableResult
    static func set(_ value: String, for key: String) -> OSStatus {
        let data = Data(value.utf8)
        remove(key)
        var status: OSStatus = errSecNotAvailable
        // Prefer an iCloud-Keychain-synced item; unsigned / restricted builds
        // can't create those, so fall back to a device-local item.
        for synchronizable in [true, false] {
            var add: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            ]
            if synchronizable { add[kSecAttrSynchronizable as String] = kCFBooleanTrue! }
            status = SecItemAdd(add as CFDictionary, nil)
            if status == errSecSuccess { return status }
        }
        return status
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
