import XCTest
@testable import Hando




private final class Clock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 2_000_000_000)
}

final class ClaudeCredentialStoreTests: XCTestCase {
    private let clock = Clock()
    private let source = FakeSource()
    private let cache = MemoryCache()
    private let refresher = FakeRefresher()

    private lazy var store = ClaudeCredentialStore(source: source, cache: cache, refresher: refresher,
                                                   now: { [clock] in clock.now })

    private func payload(token: String, expiresIn: TimeInterval) -> Keychain.ReadResult {
        let ms = Int((clock.now.timeIntervalSince1970 + expiresIn) * 1000)
        return .found(Data(#"{"claudeAiOauth":{"accessToken":"\#(token)","expiresAt":\#(ms),"subscriptionType":"pro"}}"#.utf8))
    }

    func testCopiesOnceThenUsesCache() async throws {
        source.currentVersion = Date(timeIntervalSince1970: 1)
        source.payload = payload(token: "a", expiresIn: 3600)

        let first = try await store.current(.background)
        clock.now += 120
        let second = try await store.current(.background)

        XCTAssertEqual(first.credentials.accessToken, "a")
        XCTAssertEqual(second, first)
        XCTAssertEqual(source.reads.count, 1)        // 키체인 값은 한 번만 읽음
        XCTAssertEqual(first.email, "me@example.com")
    }

    func testBackgroundNeverPrompts() async {
        source.currentVersion = Date(timeIntervalSince1970: 1)
        source.payload = payload(token: "a", expiresIn: 3600)
        source.locked = true

        do {
            _ = try await store.current(.background)
            XCTFail()
        } catch {
            XCTAssertEqual(error as? ProviderError, .needsUserAction(hint: Strings.Claude.needsPermission))
        }
        XCTAssertEqual(source.reads, [false])
    }

    func testUserActionMayPrompt() async throws {
        source.currentVersion = Date(timeIntervalSince1970: 1)
        source.payload = payload(token: "a", expiresIn: 3600)
        source.locked = true

        let entry = try await store.current(.userInitiated)
        XCTAssertEqual(entry.credentials.accessToken, "a")
        XCTAssertEqual(source.reads, [true])
    }

    func testPicksUpNewLoginWhenSourceChanges() async throws {
        source.currentVersion = Date(timeIntervalSince1970: 1)
        source.payload = payload(token: "old", expiresIn: 3600)
        _ = try await store.current(.background)

        source.currentVersion = Date(timeIntervalSince1970: 2)
        source.payload = payload(token: "new", expiresIn: 3600)
        clock.now += ClaudeCredentialStore.probeInterval + 1

        let entry = try await store.current(.background)
        XCTAssertEqual(entry.credentials.accessToken, "new")
    }

    func testExpiredAsksCLIToRefresh() async throws {
        source.currentVersion = Date(timeIntervalSince1970: 1)
        source.payload = payload(token: "old", expiresIn: 600)
        _ = try await store.current(.background)

        clock.now += 3600   // 만료
        refresher.onRefresh = { [self] in
            source.currentVersion = Date(timeIntervalSince1970: 2)
            source.payload = payload(token: "fresh", expiresIn: 3600)
        }

        let entry = try await store.current(.background)
        XCTAssertEqual(entry.credentials.accessToken, "fresh")
        XCTAssertEqual(refresher.calls, 1)
    }

    func testCLIRefreshIsThrottledInBackground() async throws {
        source.currentVersion = Date(timeIntervalSince1970: 1)
        source.payload = payload(token: "old", expiresIn: 600)
        _ = try await store.current(.background)
        clock.now += 3600   // 만료, CLI도 갱신 못 함

        for _ in 0..<3 {
            clock.now += ClaudeCredentialStore.probeInterval + 1
            _ = try? await store.current(.background)
        }
        XCTAssertEqual(refresher.calls, 1)

        _ = try? await store.current(.userInitiated)   // 사용자가 누르면 바로 다시
        XCTAssertEqual(refresher.calls, 2)
    }

    func testLogoutInCLIClearsCache() async throws {
        source.currentVersion = Date(timeIntervalSince1970: 1)
        source.payload = payload(token: "a", expiresIn: 3600)
        _ = try await store.current(.background)

        source.currentVersion = nil
        clock.now += ClaudeCredentialStore.probeInterval + 1

        do {
            _ = try await store.current(.background)
            XCTFail()
        } catch {
            guard case .notLoggedIn = error as? ProviderError else { return XCTFail() }
        }
        XCTAssertNil(cache.entry)
    }
}

final class FileClaudeCredentialCacheTests: XCTestCase {
    func testRoundTripWithPrivatePermissions() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hando-test-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = FileClaudeCredentialCache(url: url)
        let entry = CachedClaudeCredentials(
            credentials: ClaudeCredentials(accessToken: "t", expiresAt: Date(timeIntervalSince1970: 5),
                                           subscriptionType: "pro", rateLimitTier: nil),
            sourceVersion: Date(timeIntervalSince1970: 1), email: nil)

        cache.save(entry)
        XCTAssertEqual(cache.load(), entry)
        let perms = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o600)

        cache.clear()
        XCTAssertNil(cache.load())
    }
}
