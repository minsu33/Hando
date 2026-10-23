import XCTest
@testable import Hando

/// 네트워크 경로: 상태코드 → 오류 변환, 헤더, 401 때 사본 무효화, Retry-After
final class ClaudeProviderFetchTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func makeProvider(http: StubHTTP, cache: MemoryCache = MemoryCache()) -> ClaudeProvider {
        let source = FakeSource()
        source.currentVersion = Date(timeIntervalSince1970: 1)
        let ms = Int((now.timeIntervalSince1970 + 3600) * 1000)
        source.payload = .found(Data(#"{"claudeAiOauth":{"accessToken":"tok","expiresAt":\#(ms),"subscriptionType":"pro"}}"#.utf8))
        let store = ClaudeCredentialStore(source: source, cache: cache, refresher: FakeRefresher(), now: { [now] in now })
        var provider = ClaudeProvider()
        provider.http = http
        provider.credentials = store
        return provider
    }

    func testSuccessSendsHeadersAndUsesProfilePlan() async throws {
        let http = StubHTTP([
            "/usage": .init(body: try Fixture.data("claude-usage")),
            "/profile": .init(body: try Fixture.data("claude-profile")),
        ])
        let snapshot = try await makeProvider(http: http).fetch(.background)

        XCTAssertEqual(snapshot.session?.usedPercent, 40)
        XCTAssertEqual(snapshot.account.plan, "Max 5x")          // 프로필이 로그인 정보(pro)보다 우선
        let usage = try XCTUnwrap(http.requests(to: "/usage").first)
        XCTAssertEqual(usage.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        XCTAssertEqual(usage.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
        XCTAssertEqual(usage.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testProfileFailureFallsBackToCredentialPlan() async throws {
        let http = StubHTTP([
            "/usage": .init(body: try Fixture.data("claude-usage")),
            "/profile": .init(status: 500),
        ])
        let snapshot = try await makeProvider(http: http).fetch(.background)
        XCTAssertEqual(snapshot.account.plan, "Pro")
    }

    func testUnauthorizedInvalidatesCachedCredentials() async {
        let cache = MemoryCache()
        let http = StubHTTP(["/usage": .init(status: 401)])
        let provider = makeProvider(http: http, cache: cache)

        do { _ = try await provider.fetch(.background); XCTFail() } catch {
            guard case .unauthorized = error as? ProviderError else { return XCTFail("\(error)") }
        }
        XCTAssertNil(cache.entry)
    }

    func testRateLimitedPassesRetryAfter() async {
        let http = StubHTTP(["/usage": .init(status: 429, headers: ["Retry-After": "90"])])
        do { _ = try await makeProvider(http: http).fetch(.background); XCTFail() } catch {
            XCTAssertEqual(error as? ProviderError, .rateLimited(retryAfter: 90))
        }
    }

    func testGarbageBodyIsInvalidResponse() async {
        let http = StubHTTP(["/usage": .init(body: Data("<html>".utf8)), "/profile": .init(status: 500)])
        do { _ = try await makeProvider(http: http).fetch(.background); XCTFail() } catch {
            XCTAssertEqual(error as? ProviderError, .invalidResponse)
        }
    }
}

final class CodexProviderFetchTests: XCTestCase {
    private func makeProvider(http: StubHTTP, expired: Bool = false) -> CodexProvider {
        let exp = Date().timeIntervalSince1970 + (expired ? -3600 : 3600)
        let payload = try! JSONSerialization.data(withJSONObject: ["exp": exp])
        let b64 = payload.base64EncodedString().replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        let creds = CodexCredentials(accessToken: "eyJhbGciOiJub25lIn0.\(b64).sig", accountID: "acct-1", idToken: nil)
        var provider = CodexProvider()
        provider.http = http
        provider.loadCredentials = { creds }
        return provider
    }

    func testSuccessSendsAccountHeader() async throws {
        let http = StubHTTP(["/usage": .init(body: try Fixture.data("codex-usage"))])
        let snapshot = try await makeProvider(http: http).fetch(.background)

        XCTAssertEqual(snapshot.session?.usedPercent, 23)
        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "acct-1")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer eyJ") == true)
    }

    func testExpiredTokenSkipsNetwork() async {
        let http = StubHTTP(["/usage": .init(body: Data())])
        do { _ = try await makeProvider(http: http, expired: true).fetch(.background); XCTFail() } catch {
            guard case .unauthorized = error as? ProviderError else { return XCTFail("\(error)") }
        }
        XCTAssertTrue(http.requests.isEmpty)
    }

    func testStatusCodes() async {
        for (status, expected) in [(401, "unauthorized"), (429, "rateLimited"), (503, "server")] {
            let http = StubHTTP(["/usage": .init(status: status, headers: ["Retry-After": "5"])])
            do { _ = try await makeProvider(http: http).fetch(.background); XCTFail() } catch {
                let error = error as? ProviderError
                switch (status, error) {
                case (401, .unauthorized?), (429, .rateLimited(retryAfter: 5)?), (503, .server(status: 503)?): break
                default: XCTFail("\(status) → \(String(describing: error)), expected \(expected)")
                }
            }
        }
    }

    func testGarbageBodyIsInvalidResponse() async {
        let http = StubHTTP(["/usage": .init(body: Data("nope".utf8))])
        do { _ = try await makeProvider(http: http).fetch(.background); XCTFail() } catch {
            XCTAssertEqual(error as? ProviderError, .invalidResponse)
        }
    }

    // 두 창이 같은 길이면 뒤쪽은 other (팝오버 ID 충돌 방지)
    func testDuplicateWindowKindsAreSeparated() throws {
        let json = Data(#"{"rate_limit":{"primary_window":{"used_percent":10,"limit_window_seconds":604800},"secondary_window":{"used_percent":20,"limit_window_seconds":604800}}}"#.utf8)
        let snapshot = try CodexUsageResponse.decode(json).snapshot(account: .empty, now: Date())
        XCTAssertEqual(snapshot.windows.map(\.kind), [.weekly, .other(seconds: 604_800)])
    }
}

final class MenuBarStateFallbackTests: XCTestCase {
    func testLettersShowWeeklyWhenNoSessionWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let weeklyOnly = UsageSnapshot(windows: [UsageWindow(kind: .weekly, usedPercent: 60, duration: 604_800, resetsAt: now + 86_400)],
                                       account: .empty, fetchedAt: now)
        let descriptor = ProviderDescriptor(id: "codex", displayName: "Codex", menuBarLabel: "CODEX")
        let state = MenuBarState(descriptor: descriptor, state: ProviderState(snapshot: weeklyOnly, lastSuccess: now), now: now)

        XCTAssertNil(state.sessionUsed)
        XCTAssertTrue(state.lettersShowWeekly)
        XCTAssertEqual(state.letterUsed!, 0.6, accuracy: 0.001)

        // 데이터가 아예 없으면(로딩) 대체도 없음
        XCTAssertFalse(MenuBarState(descriptor: descriptor, state: ProviderState(), now: now).lettersShowWeekly)
    }
}
