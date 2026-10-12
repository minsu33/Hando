import Foundation

/// Claude Code 로그인 정보. 파일(~/.claude/.credentials.json) 먼저, 없으면 키체인
struct ClaudeCredentials: Sendable {
    let accessToken: String
    let expiresAt: Date?
    let subscriptionType: String?
    let rateLimitTier: String?

    static let keychainService = "Claude Code-credentials"

    static var configDir: URL {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    static var credentialsFile: URL { configDir.appendingPathComponent(".credentials.json") }

    /// 이메일, 조직 이름이 들어있음 (토큰은 없음)
    static var profileFile: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    /// 로그인 정보가 바뀌었는지 비교용. 값을 안 읽어서 팝업 없음
    static func currentVersion() -> Date? {
        if let date = modificationDate(credentialsFile) { return date }
        return Keychain.modificationDate(service: keychainService)
    }

    static func load() throws -> ClaudeCredentials {
        if let data = try? Data(contentsOf: credentialsFile) { return try parse(data) }
        if let data = Keychain.data(service: keychainService) { return try parse(data) }
        throw ProviderError.notLoggedIn(hint: Strings.Claude.notLoggedIn)
    }

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

    static func loadAccount(plan: String?) -> AccountInfo {
        var info = AccountInfo(plan: plan)
        guard let data = try? Data(contentsOf: profileFile),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let account = root["oauthAccount"] as? [String: Any] else { return info }
        info.email = account["emailAddress"] as? String
        return info
    }

    private static func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
