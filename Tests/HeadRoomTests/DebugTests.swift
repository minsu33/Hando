import XCTest
@testable import HeadRoom

final class DebugTests: XCTestCase {
    func testRedactsEmailAndTokens() {
        let raw = #"{"email":"someone@example.com","token":"eyJhbGciOi.eyJzdWIiOi.sig","id":"abcdefghijklmnopqrstuvwxyz0123456789"}"#
        let out = Debug.redact(raw)
        XCTAssertFalse(out.contains("someone@example.com"))
        XCTAssertFalse(out.contains("eyJhbGciOi"))
        XCTAssertFalse(out.contains("abcdefghijklmnopqrstuvwxyz0123456789"))
        XCTAssertTrue(out.contains(#""email": "***""#))
    }

    func testRedactsIdentifiersByKey() {
        let raw = #"{"user_id": "user-nwjeNAiJkyVaLF", "account_id":"short", "plan_type":"plus"}"#
        let out = Debug.redact(raw)
        XCTAssertFalse(out.contains("nwjeNAiJ"))
        XCTAssertFalse(out.contains("short"))
        XCTAssertTrue(out.contains("plus"))
    }
}
