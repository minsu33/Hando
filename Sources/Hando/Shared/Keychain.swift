import Foundation
import LocalAuthentication
import Security

/// 다른 앱(CLI)이 저장한 일반 암호 읽기 전용
enum Keychain {
    enum ReadResult: Equatable {
        case found(Data)
        case notFound
        case needsPermission    // 허용 창을 띄워야 읽을 수 있음
    }

    /// 속성(수정 시각)만 읽음. 값은 안 건드려서 허용 창이 안 뜸
    static func modificationDate(service: String) -> Date? {
        var query = baseQuery(service: service, interactive: false)
        query[kSecReturnAttributes as String] = true
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let attrs = result as? [String: Any] else { return nil }
        return attrs[kSecAttrModificationDate as String] as? Date ?? .distantPast
    }

    /// 값 읽기. interactive가 false면 허용 창이 필요할 때 띄우지 않고 needsPermission
    static func read(service: String, interactive: Bool) -> ReadResult {
        var query = baseQuery(service: service, interactive: interactive)
        query[kSecReturnData as String] = true
        var result: AnyObject?
        switch SecItemCopyMatching(query as CFDictionary, &result) {
        case errSecSuccess:
            return (result as? Data).map(ReadResult.found) ?? .notFound
        case errSecInteractionNotAllowed, errSecAuthFailed:
            return .needsPermission
        default:
            return .notFound
        }
    }

    private static func baseQuery(service: String, interactive: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if !interactive {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }
        return query
    }
}
