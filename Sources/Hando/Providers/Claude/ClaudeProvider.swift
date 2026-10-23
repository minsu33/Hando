import Foundation

// Claude 사용량 (5시간 / 주간 / 모델별 주간). claude.ai, Claude Code, Desktop 한도 공유
// 비공식 엔드포인트. 응답 확인: HANDO_DEBUG=1 swift run
struct ClaudeProvider: UsageProvider {
    let descriptor = ProviderDescriptor(id: "claude", displayName: "Claude", menuBarLabel: "CLAUDE")

    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let profileEndpoint = URL(string: "https://api.anthropic.com/api/oauth/profile")!

    var http: HTTPClient = URLSession.shared
    var credentials = ClaudeCredentialStore()
    private let profiles = ClaudeProfileCache()

    var activityFolders: [URL] { [ClaudeCodeCredentialSource.configDir.appendingPathComponent("projects")] }

    // ~/.claude.json은 쓸 때마다 바뀌어서 감시 X (키체인 변경은 수정 시각 비교로 잡힘)
    var watchedFiles: [URL] { [ClaudeCodeCredentialSource.credentialsFile] }

    var accountCommands: AccountCommands? {
        AccountCommands(binary: "claude", login: "claude auth login", logout: "claude auth logout",
                        installHint: "npm install -g @anthropic-ai/claude-code")
    }

    func hasCredentials() -> Bool {
        ClaudeCodeCredentialSource().version() != nil
    }

    func forgetCachedCredentials() {
        Task { await credentials.forget() }
    }

    func fetch(_ context: FetchContext) async throws -> UsageSnapshot {
        let entry = try await credentials.current(context)

        let token = entry.credentials.accessToken
        let (data, response) = try await http.send(Self.request(Self.endpoint, token: token))
        Debug.dump(descriptor.id, status: response.statusCode, body: data)

        guard response.statusCode == 200 else {
            if response.statusCode == 401 { await credentials.invalidate() }
            throw ProviderError(status: response.statusCode, loginHint: Strings.Claude.relogin,
                                retryAfter: response.value(forHTTPHeaderField: "Retry-After"))
        }
        let profile = await profiles.profile(token: token) { await loadProfile(token: token) }
        let account = AccountInfo(email: profile?.email ?? entry.email, plan: profile?.plan ?? entry.credentials.plan)
        return try ClaudeUsageResponse.snapshot(from: data, account: account, now: Date())
    }

    // 실패해도 사용량은 보여야 하니까 nil
    private func loadProfile(token: String) async -> ClaudeProfile? {
        guard let (data, response) = try? await http.send(Self.request(Self.profileEndpoint, token: token)) else { return nil }
        Debug.dump("\(descriptor.id) profile", status: response.statusCode, body: data)
        return response.statusCode == 200 ? ClaudeProfile.parse(data) : nil
    }

    private static func request(_ url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
