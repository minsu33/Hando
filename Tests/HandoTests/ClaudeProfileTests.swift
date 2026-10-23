import XCTest
@testable import Hando

final class ClaudeProfileTests: XCTestCase {
    // 실제 응답 형태 (Max 5x로 업그레이드한 계정, 2026-10)
    func testRealResponse() throws {
        let profile = try XCTUnwrap(ClaudeProfile.parse(Fixture.data("claude-profile")))
        XCTAssertEqual(profile.plan, "Max 5x")
        XCTAssertEqual(profile.email, "user@example.com")
    }

    func testFallbacks() {
        func plan(_ json: String) -> String? { ClaudeProfile.parse(Data(json.utf8))?.plan }
        XCTAssertEqual(plan(#"{"organization":{"rate_limit_tier":"default_claude_max_20x"}}"#), "Max 20x")
        XCTAssertEqual(plan(#"{"organization":{"organization_type":"claude_pro"}}"#), "Pro")
        XCTAssertEqual(plan(#"{"account":{"has_claude_max":true}}"#), "Max")
        XCTAssertNil(plan(#"{"account":{}}"#))
        XCTAssertNil(ClaudeProfile.parse(Data("nope".utf8)))
    }

    // 30분 안엔 다시 안 부르고, 로그인(토큰)이 바뀌면 바로 다시, 실패하면 이전 값 유지
    func testCache() async {
        let cache = ClaudeProfileCache()
        let now = Date(timeIntervalSince1970: 1_000_000)
        var calls = 0
        let pro = ClaudeProfile(plan: "Pro", email: nil)

        _ = await cache.profile(token: "a", now: now) { calls += 1; return pro }
        _ = await cache.profile(token: "a", now: now + 60) { calls += 1; return pro }
        XCTAssertEqual(calls, 1)

        _ = await cache.profile(token: "b", now: now + 60) { calls += 1; return pro }
        XCTAssertEqual(calls, 2)

        let kept = await cache.profile(token: "b", now: now + ClaudeProfileCache.maxAge + 61) { calls += 1; return nil }
        XCTAssertEqual(kept, pro)
    }
}
