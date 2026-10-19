import XCTest
@testable import Hando

final class DailyAllowanceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let day: TimeInterval = 86_400

    private func weekly(used: Double, resetIn: TimeInterval) -> UsageWindow {
        UsageWindow(kind: .weekly, usedPercent: used, duration: 7 * day, resetsAt: now + resetIn)
    }

    func testFirstDayGetsOneSeventh() {
        XCTAssertEqual(DailyAllowance.fraction(for: weekly(used: 0, resetIn: 7 * day - 3600), now: now)!, 1.0 / 7, accuracy: 0.0001)
    }

    func testLastDayGetsAll() {
        XCTAssertEqual(DailyAllowance.fraction(for: weekly(used: 0, resetIn: 3600), now: now)!, 1, accuracy: 0.0001)
    }

    func testRemainingAndOver() {
        // 3일째 (몫 42.9%)
        let resetIn = 7 * day - 2.5 * day
        XCTAssertEqual(DailyAllowance.remainingPercent(for: weekly(used: 30, resetIn: resetIn), now: now)!, 12.86, accuracy: 0.01)
        XCTAssertLessThan(DailyAllowance.remainingPercent(for: weekly(used: 60, resetIn: resetIn), now: now)!, 0)
    }

    func testUnknownResetGivesNil() {
        let w = UsageWindow(kind: .weekly, usedPercent: 10, duration: 7 * day, resetsAt: nil)
        XCTAssertNil(DailyAllowance.fraction(for: w, now: now))
    }
}
