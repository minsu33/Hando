import Foundation

/// Claude Code 로그인 정보 중 앱이 쓰는 것만. 리프레시 토큰은 안 들고 있음
struct ClaudeCredentials: Codable, Equatable, Sendable {
    let accessToken: String
    let expiresAt: Date?
    let subscriptionType: String?
    let rateLimitTier: String?

    static func parse(_ data: Data) throws -> ClaudeCredentials {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else {
            throw ProviderError.notLoggedIn(hint: Strings.Claude.notLoggedIn)
        }
        return ClaudeCredentials(accessToken: token,
                                 expiresAt: FlexibleDate.parse(oauth["expiresAt"]),
                                 subscriptionType: oauth["subscriptionType"] as? String,
                                 rateLimitTier: oauth["rateLimitTier"] as? String)
    }

    func isExpired(now: Date, leeway: TimeInterval = 60) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.addingTimeInterval(-leeway) < now
    }

    var plan: String? {
        if let tier = rateLimitTier?.lowercased() {
            if tier.contains("max_20x") { return "Max 20x" }
            if tier.contains("max_5x") { return "Max 5x" }
        }
        return subscriptionType.map { $0.prefix(1).uppercased() + $0.dropFirst() }
    }
}
