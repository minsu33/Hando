import Foundation
import Security

/// 다른 앱(CLI)이 저장한 일반 암호 읽기 전용
enum Keychain {
    /// 속성만 읽음. 값은 안 건드려서 허용 팝업이 안 뜸
    static func modificationDate(service: String) -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let attrs = result as? [String: Any] else { return nil }
        return attrs[kSecAttrModificationDate as String] as? Date ?? .distantPast
    }

    /// 값 읽기. 처음엔 macOS가 허용할지 물어봄
    static func data(service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
}
