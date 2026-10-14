import Foundation

/// Claude Code가 로그인 정보를 저장하는 곳 (읽기 전용)
protocol ClaudeCredentialSource: Sendable {
    /// 로그인 정보가 바뀌었는지 비교용. 값은 안 읽어서 허용 창 안 뜸. nil = 로그인 안 됨
    func version() -> Date?
    func read(interactive: Bool) -> Keychain.ReadResult
    func email() -> String?
}

/// ~/.claude/.credentials.json 먼저, 없으면 키체인 "Claude Code-credentials"
struct ClaudeCodeCredentialSource: ClaudeCredentialSource {
    static let keychainService = "Claude Code-credentials"

    static var configDir: URL {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    static var credentialsFile: URL { configDir.appendingPathComponent(".credentials.json") }

    /// 이메일 들어있음 (토큰 없음)
    static var profileFile: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    func version() -> Date? {
        if let date = (try? FileManager.default.attributesOfItem(atPath: Self.credentialsFile.path))?[.modificationDate] as? Date {
            return date
        }
        return Keychain.modificationDate(service: Self.keychainService)
    }

    func read(interactive: Bool) -> Keychain.ReadResult {
        if let data = try? Data(contentsOf: Self.credentialsFile) { return .found(data) }
        return Keychain.read(service: Self.keychainService, interactive: interactive)
    }

    func email() -> String? {
        guard let data = try? Data(contentsOf: Self.profileFile),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let account = root["oauthAccount"] as? [String: Any] else { return nil }
        return account["emailAddress"] as? String
    }
}
