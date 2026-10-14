import Foundation

/// ~/.codex/auth.json (codex login 하면 생김). 읽기만 함
struct CodexCredentials: Sendable {
    let accessToken: String
    let accountID: String?
    let idToken: String?

    static var authFile: URL {
        let env = ProcessInfo.processInfo.environment["CODEX_HOME"]
        let home = env.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        return home.appendingPathComponent("auth.json")
    }

    static func load(from url: URL = authFile) throws -> CodexCredentials {
        guard let data = try? Data(contentsOf: url) else {
            throw ProviderError.notLoggedIn(hint: Strings.Codex.noAuthFile)
        }
        return try parse(data)
    }

    static func parse(_ data: Data) throws -> CodexCredentials {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let file = try? decoder.decode(AuthFile.self, from: data),
              let access = file.tokens?.accessToken, !access.isEmpty else {
            throw ProviderError.notLoggedIn(hint: Strings.Codex.noChatGPTLogin)
        }
        return CodexCredentials(accessToken: access,
                                accountID: file.tokens?.accountId,
                                idToken: file.tokens?.idToken)
    }

    // access_token의 exp 기준. exp 없으면 모르니까 일단 보냄
    func isExpired(now: Date, leeway: TimeInterval = 60) -> Bool {
        guard let exp = JWT.payload(accessToken).flatMap({ FlexibleDate.parse($0["exp"]) }) else { return false }
        return exp.addingTimeInterval(-leeway) < now
    }

    // id_token에서 이메일, 플랜, 구독 만료일
    var account: AccountInfo {
        guard let idToken, let claims = JWT.payload(idToken) else { return .empty }
        var info = AccountInfo(email: claims["email"] as? String)
        if let auth = claims["https://api.openai.com/auth"] as? [String: Any] {
            info.plan = auth["chatgpt_plan_type"] as? String
            info.subscriptionEndsAt = FlexibleDate.parse(auth["chatgpt_subscription_active_until"])
        }
        return info
    }

    private struct AuthFile: Decodable {
        struct Tokens: Decodable {
            let idToken: String?
            let accessToken: String?
            let accountId: String?

            enum CodingKeys: String, CodingKey { case idToken, accessToken, accountId }

            // 필드 하나 없어도 안 죽게
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                idToken = try? c.decode(String.self, forKey: .idToken)
                accessToken = try? c.decode(String.self, forKey: .accessToken)
                accountId = try? c.decode(String.self, forKey: .accountId)
            }
        }
        let tokens: Tokens?
    }
}
