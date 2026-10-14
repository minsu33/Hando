import XCTest
@testable import Hando

final class ClaudeParsingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_330_000)

    // 실제 응답 (Pro, 2026-10). 모르는 필드가 잔뜩 있어도 5시간/주간만 뽑혀야 함
    func testRealResponse() throws {
        let snapshot = try ClaudeUsageResponse.snapshot(from: Fixture.data("claude-usage"), account: .empty, now: now)

        XCTAssertEqual(snapshot.session?.usedPercent, 40)
        XCTAssertEqual(snapshot.weekly?.usedPercent, 5)
        XCTAssertTrue(snapshot.extraWindows.isEmpty)
        XCTAssertNotNil(snapshot.session?.resetsAt)   // 마이크로초까지 붙어서 옴
        XCTAssertEqual(snapshot.session?.resetsAt, FlexibleDate.iso("2026-10-12T20:10:00.336111+00:00"))
    }

    func testModelWindow() throws {
        let snapshot = try ClaudeUsageResponse.snapshot(from: Fixture.data("claude-usage-with-opus"), account: .empty, now: now)

        XCTAssertEqual(snapshot.session?.usedPercent, 38)
        XCTAssertEqual(snapshot.session?.duration, 5 * 3600)
        XCTAssertEqual(snapshot.weekly?.usedPercent, 52)
        XCTAssertEqual(snapshot.extraWindows.map(\.kind), [.weeklyModel("Opus")])   // null인 sonnet은 빠짐
        XCTAssertNotNil(snapshot.session?.resetsAt)
    }

    func testGarbage() {
        XCTAssertThrowsError(try ClaudeUsageResponse.snapshot(from: Data("[]".utf8), account: .empty, now: now))
    }

    func testCredentials() throws {
        let json = Data(#"{"claudeAiOauth":{"accessToken":"tok","expiresAt":1760330000000,"subscriptionType":"max","rateLimitTier":"default_claude_max_5x"}}"#.utf8)
        let creds = try ClaudeCredentials.parse(json)

        XCTAssertEqual(creds.expiresAt, Date(timeIntervalSince1970: 1_760_330_000))   // ms
        XCTAssertEqual(creds.plan, "Max 5x")
        XCTAssertTrue(creds.isExpired(now: now))
        XCTAssertFalse(creds.isExpired(now: now.addingTimeInterval(-3600)))
    }

    func testPlanFallsBackToSubscriptionType() throws {
        let json = Data(#"{"claudeAiOauth":{"accessToken":"tok","subscriptionType":"pro"}}"#.utf8)
        XCTAssertEqual(try ClaudeCredentials.parse(json).plan, "Pro")
    }

    func testMissingTokenIsNotLoggedIn() {
        XCTAssertThrowsError(try ClaudeCredentials.parse(Data(#"{"claudeAiOauth":{}}"#.utf8))) {
            guard case .notLoggedIn = $0 as? ProviderError else { return XCTFail() }
        }
    }
}
