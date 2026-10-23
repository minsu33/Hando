import XCTest
@testable import Hando

final class StatusLineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func snapshot(session: Double?, weekly: Double, dayOfWeek: Int = 3, fetchedAgo: TimeInterval = 0) -> UsageSnapshot {
        // dayOfWeek일째 (몫 dayOfWeek/7)
        let resetIn = 7 * 86_400 - (Double(dayOfWeek) - 0.5) * 86_400
        var windows = [UsageWindow(kind: .weekly, usedPercent: weekly, duration: 7 * 86_400, resetsAt: now + resetIn)]
        if let session { windows.insert(UsageWindow(kind: .session, usedPercent: session, duration: 18_000, resetsAt: now + 3600), at: 0) }
        return UsageSnapshot(windows: windows, account: .empty, fetchedAt: now - fetchedAgo)
    }

    func testNormalLine() {
        // 주간 30% = 2.1칸 → ▓▓ / 3일째 몫 3칸 → 세 번째는 ▒ / 나머지 ░
        let line = StatusLine.render(label: "CLAUDE", snapshot: snapshot(session: 42, weekly: 30), now: now, fromCache: true)
        XCTAssertEqual(line, "CLAUDE 5h 42% ▓▓▒░░░░")
    }

    func testNoSessionShowsWeekly() {
        let line = StatusLine.render(label: "CODEX", snapshot: snapshot(session: nil, weekly: 60), now: now, fromCache: true)
        XCTAssertTrue(line.hasPrefix("CODEX 주 60% "))
    }

    func testStaleCacheSaysHowOld() {
        let line = StatusLine.render(label: "CLAUDE", snapshot: snapshot(session: 10, weekly: 5, fetchedAgo: 600), now: now, fromCache: true)
        XCTAssertTrue(line.hasSuffix(" · 10분 전"), line)
        // stdin에서 온 값은 항상 최신
        let fresh = StatusLine.render(label: "CLAUDE", snapshot: snapshot(session: 10, weekly: 5, fetchedAgo: 600), now: now, fromCache: false)
        XCTAssertFalse(fresh.contains("전"))
    }

    func testNoData() {
        XCTAssertEqual(StatusLine.render(label: "CLAUDE", snapshot: nil, now: now, fromCache: true), "CLAUDE —")
    }

    func testParsesClaudeCodeInput() throws {
        let json = #"{"model":{"id":"x"},"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":2000003600},"seven_day":{"used_percentage":30.5,"resets_at":"2033-05-25T03:33:20Z"}}}"#
        let snapshot = try XCTUnwrap(StatusLine.parseClaudeCode(Data(json.utf8), now: now))
        XCTAssertEqual(snapshot.session?.usedPercent, 42)
        XCTAssertEqual(snapshot.weekly?.usedPercent, 30.5)
        XCTAssertEqual(snapshot.session?.resetsAt, Date(timeIntervalSince1970: 2_000_003_600))
        XCTAssertNotNil(snapshot.weekly?.resetsAt)
    }

    func testIgnoresInputWithoutRateLimits() {
        XCTAssertNil(StatusLine.parseClaudeCode(Data(#"{"model":{"id":"x"}}"#.utf8)))
        XCTAssertNil(StatusLine.parseClaudeCode(Data("not json".utf8)))
    }
}
