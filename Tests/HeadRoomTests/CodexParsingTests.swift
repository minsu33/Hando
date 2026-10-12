import XCTest
@testable import HeadRoom

final class CodexParsingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_390_000)

    func testSessionAndWeekly() throws {
        let snapshot = try CodexUsageResponse.decode(Fixture.data("codex-usage"))
            .snapshot(account: .empty, now: now)

        XCTAssertEqual(snapshot.session?.usedPercent, 23)
        XCTAssertEqual(snapshot.weekly?.usedPercent, 41)
        XCTAssertEqual(snapshot.session?.resetsAt, Date(timeIntervalSince1970: 1_760_400_000))
        XCTAssertEqual(snapshot.account.plan, "Plus")
        XCTAssertTrue(snapshot.extraWindows.isEmpty)
    }

    func testWeeklyOnlyPlanHasNoSession() throws {
        let snapshot = try CodexUsageResponse.decode(Fixture.data("codex-usage-weekly-only"))
            .snapshot(account: .empty, now: now)

        // 실제 응답 형태 (Pro Lite: 주간만 있음)
        XCTAssertNil(snapshot.session)
        XCTAssertEqual(snapshot.weekly?.usedPercent, 21)
        XCTAssertEqual(snapshot.weekly?.resetsAt, Date(timeIntervalSince1970: 1_792_295_861))
        XCTAssertEqual(snapshot.account.plan, "Pro Lite")
    }

    func testResetAfterSecondsWhenNoResetAt() throws {
        let json = Data(#"{"rate_limit":{"primary_window":{"used_percent":5,"limit_window_seconds":18000,"reset_after_seconds":100}}}"#.utf8)
        let snapshot = try CodexUsageResponse.decode(json).snapshot(account: .empty, now: now)
        XCTAssertEqual(snapshot.session?.resetsAt, now.addingTimeInterval(100))
    }

    func testWindowKindBySeconds() {
        XCTAssertEqual(CodexUsageResponse.kind(forSeconds: 18_000, fallback: .weekly), .session)
        XCTAssertEqual(CodexUsageResponse.kind(forSeconds: 604_800, fallback: .session), .weekly)
        XCTAssertEqual(CodexUsageResponse.kind(forSeconds: 3_600, fallback: .session), .other(seconds: 3_600))
        XCTAssertEqual(CodexUsageResponse.kind(forSeconds: nil, fallback: .weekly), .weekly)
    }

    func testGarbageThrowsInvalidResponse() {
        XCTAssertThrowsError(try CodexUsageResponse.decode(Data("nope".utf8))) {
            XCTAssertEqual($0 as? ProviderError, .invalidResponse)
        }
    }

    func testPrettyPlan() {
        XCTAssertEqual(CodexUsageResponse.prettyPlan("chatgpt_team"), "Chatgpt Team")
    }

    func testCredentialsNeedAccessToken() {
        let json = Data(#"{"tokens":{"id_token":"x"}}"#.utf8)
        XCTAssertThrowsError(try CodexCredentials.parse(json))

        let ok = Data(#"{"tokens":{"access_token":"abc","account_id":"acc"}}"#.utf8)
        XCTAssertEqual(try CodexCredentials.parse(ok).accountID, "acc")
    }
}
