import XCTest
@testable import HeadRoom

final class MenuBarStateTests: XCTestCase {
    private let codex = ProviderDescriptor(id: "codex", displayName: "Codex", menuBarLabel: "codex")
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func snapshot(session: Double?, weekly: Double) -> UsageSnapshot {
        var windows = [UsageWindow(kind: .weekly, usedPercent: weekly, duration: nil, resetsAt: nil)]
        if let session {
            windows.append(UsageWindow(kind: .session, usedPercent: session, duration: nil, resetsAt: nil))
        }
        return UsageSnapshot(windows: windows, account: .empty, fetchedAt: now)
    }

    func testLoadingBeforeFirstResult() {
        let state = MenuBarState(descriptor: codex, state: ProviderState(), now: now)
        XCTAssertEqual(state.status, .loading)
        XCTAssertEqual(state.label, "CODEX")
    }

    func testErrorWithoutData() {
        var s = ProviderState()
        s.error = .rateLimited
        XCTAssertEqual(MenuBarState(descriptor: codex, state: s, now: now).status, .error)
    }

    func testKeepsLastValuesOnErrorUntilStale() {
        var s = ProviderState(snapshot: snapshot(session: 40, weekly: 70), error: .rateLimited,
                              lastSuccess: now.addingTimeInterval(-60))
        var menu = MenuBarState(descriptor: codex, state: s, now: now)
        XCTAssertEqual(menu.status, .normal)
        XCTAssertEqual(menu.sessionUsed!, 0.4, accuracy: 0.0001)
        XCTAssertEqual(menu.weeklyUsed!, 0.7, accuracy: 0.0001)

        s.lastSuccess = now.addingTimeInterval(-ProviderState.staleAfter - 1)
        menu = MenuBarState(descriptor: codex, state: s, now: now)
        XCTAssertEqual(menu.status, .stale)
    }

    func testNoSessionWindow() {
        let s = ProviderState(snapshot: snapshot(session: nil, weekly: 10), lastSuccess: now)
        XCTAssertNil(MenuBarState(descriptor: codex, state: s, now: now).sessionUsed)
    }

    func testClampsValues() {
        let state = MenuBarState(label: "x", sessionUsed: 1.4, weeklyUsed: -1, status: .normal)
        XCTAssertEqual(state.sessionUsed, 1)
        XCTAssertEqual(state.weeklyUsed, 0)
    }
}
