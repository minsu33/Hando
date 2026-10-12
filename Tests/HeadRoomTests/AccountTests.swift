import XCTest
@testable import HeadRoom

final class AccountTests: XCTestCase {
    private let codex = CodexProvider().accountCommands!

    func testSwitchRunsLogoutThenLogin() {
        let script = codex.script(for: .switchAccount)
        XCTAssertTrue(script.contains("codex logout && codex login"))
        XCTAssertTrue(script.contains("command -v codex"))
    }

    func testLoginOnly() {
        let script = codex.script(for: .login)
        XCTAssertTrue(script.contains("codex login"))
        XCTAssertFalse(script.contains("logout"))
    }

    private func token(exp: TimeInterval) -> String {
        let payload = try! JSONSerialization.data(withJSONObject: ["exp": exp])
        let b64 = payload.base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        return "eyJhbGciOiJub25lIn0.\(b64).sig"
    }

    func testExpiredToken() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let expired = CodexCredentials(accessToken: token(exp: 1_999_999_000), accountID: nil, idToken: nil)
        let valid = CodexCredentials(accessToken: token(exp: 2_000_003_600), accountID: nil, idToken: nil)
        let opaque = CodexCredentials(accessToken: "not-a-jwt", accountID: nil, idToken: nil)

        XCTAssertTrue(expired.isExpired(now: now))
        XCTAssertFalse(valid.isExpired(now: now))
        XCTAssertFalse(opaque.isExpired(now: now))
    }
}
