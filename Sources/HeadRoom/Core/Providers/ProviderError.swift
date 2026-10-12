import Foundation

enum ProviderError: Error, Equatable, Sendable {
    case notLoggedIn(hint: String)
    case unauthorized(hint: String)
    case rateLimited
    case server(status: Int)
    case invalidResponse
    case network(String)

    init(status: Int, loginHint: String) {
        switch status {
        case 401, 403: self = .unauthorized(hint: loginHint)
        case 429: self = .rateLimited
        default: self = .server(status: status)
        }
    }

    var message: String {
        switch self {
        case .notLoggedIn(let hint): return hint
        case .unauthorized(let hint): return "\(Strings.Error.expired) \(hint)"
        case .rateLimited: return Strings.Error.rateLimited
        case .server(let status): return Strings.Error.server(status)
        case .invalidResponse: return Strings.Error.invalidResponse
        case .network(let reason): return "\(Strings.Error.network) (\(reason))"
        }
    }
}
