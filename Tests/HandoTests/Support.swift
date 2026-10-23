import Foundation
@testable import Hando

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }
}

// MARK: - Claude 로그인 정보 가짜들 (여러 테스트에서 공용)

final class FakeSource: ClaudeCredentialSource, @unchecked Sendable {
    var currentVersion: Date?
    var payload: Keychain.ReadResult = .notFound
    var locked = false              // 허용 창 필요한 상태
    private(set) var reads: [Bool] = []   // interactive 여부 기록

    func version() -> Date? { currentVersion }
    func read(interactive: Bool) -> Keychain.ReadResult {
        reads.append(interactive)
        return locked && !interactive ? .needsPermission : payload
    }
    func email() -> String? { "me@example.com" }
}

final class MemoryCache: ClaudeCredentialCache, @unchecked Sendable {
    var entry: CachedClaudeCredentials?
    func load() -> CachedClaudeCredentials? { entry }
    func save(_ entry: CachedClaudeCredentials) { self.entry = entry }
    func clear() { entry = nil }
}

final class FakeRefresher: ClaudeCLIRefresher, @unchecked Sendable {
    var calls = 0
    var onRefresh: () -> Void = {}
    func refresh() async { calls += 1; onRefresh() }
}

/// URL별로 정해둔 응답을 주는 가짜 네트워크. 보낸 요청은 기록
final class StubHTTP: HTTPClient, @unchecked Sendable {
    struct Reply { var status = 200; var body = Data(); var headers: [String: String] = [:] }

    var replies: [String: Reply] = [:]      // URL path 뒤쪽으로 매칭 ("/usage", "/profile")
    private(set) var requests: [URLRequest] = []

    init(_ replies: [String: Reply] = [:]) { self.replies = replies }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let path = request.url?.path ?? ""
        guard let reply = replies.first(where: { path.hasSuffix($0.key) })?.value else {
            throw ProviderError.network("stub: no reply for \(path)")
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil,
                                       headerFields: reply.headers)!
        return (reply.body, response)
    }

    func requests(to suffix: String) -> [URLRequest] { requests.filter { ($0.url?.path ?? "").hasSuffix(suffix) } }
}
