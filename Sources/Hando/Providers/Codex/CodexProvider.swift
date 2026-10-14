import Foundation

// Codex 사용량 (5시간 / 주간)
// 비공식 엔드포인트라 언제든 바뀔 수 있음. 응답 확인: HANDO_DEBUG=1 swift run
struct CodexProvider: UsageProvider {
    let descriptor = ProviderDescriptor(id: "codex", displayName: "Codex", menuBarLabel: "CODEX")

    private static let endpoint = URL(string: "https://chatgpt.com/backend-api/codex/usage")!

    var http: HTTPClient = URLSession.shared
    var loadCredentials: @Sendable () throws -> CodexCredentials = { try CodexCredentials.load() }

    var watchedFiles: [URL] { [CodexCredentials.authFile] }

    var activityFolders: [URL] {
        [CodexCredentials.authFile.deletingLastPathComponent().appendingPathComponent("sessions")]
    }

    var accountCommands: AccountCommands? {
        AccountCommands(binary: "codex", login: "codex login", logout: "codex logout",
                        installHint: "npm install -g @openai/codex")
    }

    func hasCredentials() -> Bool {
        (try? loadCredentials()) != nil
    }

    func fetch(_ context: FetchContext) async throws -> UsageSnapshot {
        let creds = try loadCredentials()
        // 만료된 토큰은 요청 안 보냄. 갱신은 CLI가 함
        if creds.isExpired(now: Date()) {
            throw ProviderError.unauthorized(hint: Strings.Codex.relogin)
        }

        var request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID = creds.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try await http.send(request)
        Debug.dump(descriptor.id, status: response.statusCode, body: data)

        guard response.statusCode == 200 else {
            throw ProviderError(status: response.statusCode, loginHint: Strings.Codex.relogin,
                                retryAfter: response.value(forHTTPHeaderField: "Retry-After"))
        }
        return try CodexUsageResponse.decode(data).snapshot(account: creds.account, now: Date())
    }
}
