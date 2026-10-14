import Foundation

enum ProviderError: Error, Equatable, Sendable {
    case notLoggedIn(hint: String)
    case unauthorized(hint: String)
    case needsUserAction(hint: String)   // 백그라운드에선 못 하고 사용자가 눌러야 되는 것
    case rateLimited(retryAfter: TimeInterval?)   // 서버가 Retry-After 주면 그만큼 쉼
    case server(status: Int)
    case invalidResponse
    case network(String)

    init(status: Int, loginHint: String, retryAfter: String? = nil) {
        switch status {
        case 401, 403: self = .unauthorized(hint: loginHint)
        case 429: self = .rateLimited(retryAfter: retryAfter.flatMap(TimeInterval.init))
        default: self = .server(status: status)
        }
    }

    /// 사용자가 뭔가 해야 풀리는 오류 (로그인, 키체인 허용)
    var needsAttention: Bool {
        switch self {
        case .notLoggedIn, .unauthorized, .needsUserAction: return true
        case .rateLimited, .server, .invalidResponse, .network: return false
        }
    }

    var message: String {
        switch self {
        case .notLoggedIn(let hint): return hint
        case .unauthorized(let hint): return "\(Strings.Error.expired) \(hint)"
        case .needsUserAction(let hint): return hint
        case .rateLimited: return Strings.Error.rateLimited
        case .server(let status): return Strings.Error.server(status)
        case .invalidResponse: return Strings.Error.invalidResponse
        case .network(let reason): return "\(Strings.Error.network) (\(reason))"
        }
    }
}
