import XCTest
@testable import HeadRoom

private final class StubProvider: UsageProvider, @unchecked Sendable {
    let descriptor: ProviderDescriptor
    var result: Result<UsageSnapshot, ProviderError>

    init(id: String, result: Result<UsageSnapshot, ProviderError>) {
        descriptor = ProviderDescriptor(id: id, displayName: id, menuBarLabel: id)
        self.result = result
    }

    func hasCredentials() -> Bool { true }
    func fetch() async throws -> UsageSnapshot { try result.get() }
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

        store.select(StubProvider(id: "b", result: .failure(.rateLimited)))
        XCTAssertEqual(store.provider.descriptor.id, "b")
        XCTAssertNil(store.state.lastSuccess)
    }
}

@MainActor
final class UsageStoreTimingTests: XCTestCase {
    func testFasterWhileActiveThenBackToNormal() {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let store = UsageStore(provider: StubProvider(id: "a", result: .failure(.rateLimited)), interval: { 120 }, now: { clock })

        XCTAssertEqual(store.nextDelay(), 120)
        store.noteActivity()
        XCTAssertEqual(store.nextDelay(), UsageStore.activeInterval)

        clock += UsageStore.activeWindow + 1
        XCTAssertEqual(store.nextDelay(), 120)
    }
}
