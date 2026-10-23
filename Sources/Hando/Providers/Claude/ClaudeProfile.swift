import Foundation

/// GET api.anthropic.com/api/oauth/profile: 지금 계정의 실제 플랜
/// 로그인할 때 저장된 subscriptionType은 업그레이드해도 다시 로그인하기 전까지 안 바뀜 → 이걸로 덮어씀
struct ClaudeProfile: Equatable, Sendable {
    let plan: String?
    let email: String?

    static func parse(_ data: Data) -> ClaudeProfile? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let account = root["account"] as? [String: Any]
        let org = root["organization"] as? [String: Any]
        return ClaudeProfile(plan: plan(account: account, org: org),
                             email: account?["email_address"] as? String ?? account?["email"] as? String)
    }

    // 필드 이름이 바뀔 수 있어서 아는 것들을 순서대로 봄
    private static func plan(account: [String: Any]?, org: [String: Any]?) -> String? {
        let tier = (org?["rate_limit_tier"] as? String)?.lowercased() ?? ""
        if tier.contains("max_20x") { return "Max 20x" }
        if tier.contains("max_5x") { return "Max 5x" }

        let type = (org?["organization_type"] as? String)?.lowercased() ?? ""
        if type.contains("max") || account?["has_claude_max"] as? Bool == true { return "Max" }
        if type.contains("pro") || account?["has_claude_pro"] as? Bool == true { return "Pro" }
        if type.contains("team") { return "Team" }
        if type.contains("enterprise") { return "Enterprise" }
        return nil
    }
}

/// 프로필은 자주 안 바뀌니까 30분에 한 번만, 로그인이 바뀌면 바로 다시
actor ClaudeProfileCache {
    static let maxAge: TimeInterval = 30 * 60

    private var cached: (token: String, at: Date, profile: ClaudeProfile?)?

    func profile(token: String, now: Date = Date(), load: () async -> ClaudeProfile?) async -> ClaudeProfile? {
        if let cached, cached.token == token, now.timeIntervalSince(cached.at) < Self.maxAge {
            return cached.profile
        }
        let profile = await load()
        cached = (token, now, profile ?? cached?.profile)   // 실패하면 이전 값 유지
        return cached?.profile
    }
}
