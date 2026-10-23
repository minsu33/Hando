import XCTest
@testable import Hando

final class StubProvider: UsageProvider, @unchecked Sendable {
    let descriptor: ProviderDescriptor
    var result: Result<UsageSnapshot, ProviderError>

    init(id: String, result: Result<UsageSnapshot, ProviderError>) {
        descriptor = ProviderDescriptor(id: id, displayName: id, menuBarLabel: id)
        self.result = result
    }

    func hasCredentials() -> Bool { true }
    func fetch(_ context: FetchContext) async throws -> UsageSnapshot { try result.get() }
}

@MainActor
final class UsageStoreTests: XCTestCase {
    private let snapshot = UsageSnapshot(windows: [], account: .empty, fetchedAt: Date())

    func testSuccessThenFailureKeepsSnapshot() async {
        let provider = StubProvider(id: "a", result: .success(snapshot))
        let store = UsageStore(provider: provider, interval: { 120 })

        await store.refresh()
        XCTAssertNotNil(store.state.snapshot)
        XCTAssertNotNil(store.state.lastSuccess)

        provider.result = .failure(.server(status: 500))
        await store.refresh()
        XCTAssertNotNil(store.state.snapshot)
        XCTAssertEqual(store.state.error, .server(status: 500))
        XCTAssertFalse(store.state.isRefreshing)
    }

    func testSelectResetsState() async {
        let store = UsageStore(provider: StubProvider(id: "a", result: .success(snapshot)), interval: { 120 })
        await store.refresh()

        store.select(StubProvider(id: "b", result: .failure(.rateLimited(retryAfter: nil))))
        XCTAssertEqual(store.provider.descriptor.id, "b")
        XCTAssertNil(store.state.lastSuccess)
    }
}

@MainActor
final class UsageStoreTimingTests: XCTestCase {
    func testFasterWhileActiveThenBackToNormal() {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let store = UsageStore(provider: StubProvider(id: "a", result: .failure(.rateLimited(retryAfter: nil))), interval: { 120 }, now: { clock })

        XCTAssertEqual(store.nextDelay(), 120)
        store.noteActivity()
        XCTAssertEqual(store.nextDelay(), UsageStore.activeInterval)

        clock += UsageStore.activeWindow + 1
        XCTAssertEqual(store.nextDelay(), 120)
    }
}

private final class MemorySnapshots: SnapshotCache, @unchecked Sendable {
    var stored: [String: UsageSnapshot] = [:]
    func load(providerID: String) -> UsageSnapshot? { stored[providerID] }
    func save(_ snapshot: UsageSnapshot, providerID: String) { stored[providerID] = snapshot }
}

@MainActor
final class UsageStorePersistenceTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_000_000)

    private func snapshot(at date: Date) -> UsageSnapshot {
        UsageSnapshot(windows: [UsageWindow(kind: .session, usedPercent: 30, duration: 18_000, resetsAt: nil)],
                      account: AccountInfo(email: "a@b.c", plan: "Pro"), fetchedAt: date)
    }

    func testShowsLastValuesOnLaunchAndWaitsIfFresh() {
        let cache = MemorySnapshots()
        cache.stored["a"] = snapshot(at: base.addingTimeInterval(-30))
        let store = UsageStore(provider: StubProvider(id: "a", result: .failure(.invalidResponse)),
                               interval: { 120 }, snapshots: cache, now: { [base] in base })

        XCTAssertEqual(store.state.snapshot?.session?.usedPercent, 30)
        XCTAssertEqual(store.initialDelay(), 90, accuracy: 0.001)   // 30초 전 값 → 90초 뒤 첫 요청
    }

    func testOldValuesFetchRightAway() {
        let cache = MemorySnapshots()
        cache.stored["a"] = snapshot(at: base.addingTimeInterval(-600))
        let store = UsageStore(provider: StubProvider(id: "a", result: .failure(.invalidResponse)),
                               interval: { 120 }, snapshots: cache, now: { [base] in base })
        XCTAssertEqual(store.initialDelay(), 0)
    }

    func testSavesOnSuccess() async {
        let cache = MemorySnapshots()
        let store = UsageStore(provider: StubProvider(id: "a", result: .success(snapshot(at: base))),
                               interval: { 120 }, snapshots: cache)
        await store.refresh()
        XCTAssertNotNil(cache.stored["a"])
    }

    func testRespectsRetryAfter() async {
        let store = UsageStore(provider: StubProvider(id: "a", result: .failure(.rateLimited(retryAfter: 600))),
                               interval: { 120 })
        await store.refresh()
        XCTAssertEqual(store.nextDelay(), 600)
    }

    func testBacksOffWithoutRetryAfter() async {
        let store = UsageStore(provider: StubProvider(id: "a", result: .failure(.rateLimited(retryAfter: nil))),
                               interval: { 120 })
        await store.refresh()
        XCTAssertEqual(store.nextDelay(), 120)
        await store.refresh()
        XCTAssertEqual(store.nextDelay(), 240)
    }

    func testSnapshotCodableRoundTrip() throws {
        let original = UsageSnapshot(windows: [
            UsageWindow(kind: .weeklyModel("Opus"), usedPercent: 12, duration: nil, resetsAt: base),
            UsageWindow(kind: .other(seconds: 3600), usedPercent: 1, duration: 3600, resetsAt: nil),
        ], account: .empty, fetchedAt: base)
        let decoded = try JSONDecoder().decode(UsageSnapshot.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.windows, original.windows)
    }
}

@MainActor
final class UsageStoreWakeTests: XCTestCase {
    func testWakeRefreshesUnlessJustFetched() async {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let snapshot = UsageSnapshot(windows: [], account: .empty, fetchedAt: clock)
        let store = UsageStore(provider: StubProvider(id: "a", result: .success(snapshot)), interval: { 120 }, now: { clock })

        XCTAssertTrue(store.refreshAfterWake())        // 처음엔 바로
        await store.refresh()                          // 방금 가져옴
        clock += 10
        XCTAssertFalse(store.refreshAfterWake())       // 10초 뒤 깨어남 → 건너뜀
        clock += UsageStore.wakeGap
        XCTAssertTrue(store.refreshAfterWake())        // 충분히 지나면 다시
    }
}

@MainActor
final class UsageStoreQueuedRefreshTests: XCTestCase {
    /// 느린 가짜: fetch가 신호를 줄 때까지 기다림
    private final class SlowProvider: UsageProvider, @unchecked Sendable {
        let descriptor = ProviderDescriptor(id: "slow", displayName: "Slow", menuBarLabel: "SLOW")
        var contexts: [FetchContext] = []
        var release: CheckedContinuation<Void, Never>?
        func hasCredentials() -> Bool { true }
        func fetch(_ context: FetchContext) async throws -> UsageSnapshot {
            contexts.append(context)
            if contexts.count == 1 { await withCheckedContinuation { release = $0 } }
            return UsageSnapshot(windows: [], account: .empty, fetchedAt: Date())
        }
    }

    // 백그라운드 갱신 중에 사용자가 누르면 버리지 않고 끝난 뒤 한 번 더
    func testUserRefreshDuringBackgroundIsQueued() async {
        let provider = SlowProvider()
        let store = UsageStore(provider: provider, interval: { 120 })

        let background = Task { await store.refresh(.background) }
        while provider.release == nil { await Task.yield() }
        await store.refresh(.userInitiated)          // 갱신 중 → 큐에
        provider.release?.resume()
        await background.value

        XCTAssertEqual(provider.contexts, [.background, .userInitiated])
    }
}
