import Foundation

// Claude 사용량 (5시간 / 주간 / 모델별 주간). claude.ai, Claude Code, Desktop 한도 공유
// 비공식 엔드포인트. 응답 확인: HEADROOM_DEBUG=1 swift run
struct ClaudeProvider: UsageProvider {
    let descriptor = ProviderDescriptor(id: "claude", displayName: "Claude", menuBarLabel: "CLAUDE")

    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    var http: HTTPClient = URLSession.shared
    private let cache = CredentialCache()

    var activityFolders: [URL] { [ClaudeCredentials.configDir.appendingPathComponent("projects")] }

    // ~/.claude.json은 쓸 때마다 바뀌어서 감시 X (키체인 변경은 fetch 때 버전 비교로 잡힘)
    var watchedFiles: [URL] { [ClaudeCredentials.credentialsFile] }

    var accountCommands: AccountCommands? {
        AccountCommands(binary: "claude", login: "claude auth login", logout: "claude auth logout",
                        installHint: "npm install -g @anthropic-ai/claude-code")
    }

    func hasCredentials() -> Bool {
        ClaudeCredentials.currentVersion() != nil
    }

    func fetch() async throws -> UsageSnapshot {
        let (creds, account) = try await cache.current()
        if creds.isExpired(now: Date()) {
            await cache.invalidate()
            throw ProviderError.unauthorized(hint: Strings.Claude.relogin)
        }

        var request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await http.send(request)
        Debug.dump(descriptor.id, status: response.statusCode, body: data)

        guard response.statusCode == 200 else {
            if response.statusCode == 401 { await cache.invalidate() }
            throw ProviderError(status: response.statusCode, loginHint: Strings.Claude.relogin)
        }
        return try ClaudeUsageResponse.snapshot(from: data, account: account, now: Date())
    }
}

/// 키체인은 읽을 때마다 허용 팝업이 뜰 수 있어서, 로그인 정보가 바뀌었을 때만 다시 읽음
private actor CredentialCache {
    private var cached: (version: Date?, creds: ClaudeCredentials, account: AccountInfo)?

    func current() throws -> (ClaudeCredentials, AccountInfo) {
        let version = ClaudeCredentials.currentVersion()
        if let cached, cached.version == version {
            return (cached.creds, cached.account)
        }
        let creds = try ClaudeCredentials.load()
        let account = ClaudeCredentials.loadAccount(plan: creds.plan)
        cached = (version, creds, account)
        return (creds, account)
    }

    func invalidate() { cached = nil }
}
