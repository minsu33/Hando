import XCTest
@testable import Hando

final class TypefaceTests: XCTestCase {
    func testLineup() {
        let ids = TypefaceCatalog.all.map(\.id)
        XCTAssertEqual(ids, ["system", "terminal", "pixel", "crt", "poster", "gauge", "typewriter"])
        XCTAssertEqual(TypefaceCatalog.typeface(id: "없는거").id, TypefaceCatalog.defaultID)
    }

    // 높이: 폰트 대문자 높이 = 픽셀 글꼴 높이
    func testCapHeightsMatchPixel() {
        for case let typeface as FontTypeface in TypefaceCatalog.all {
            XCTAssertEqual(typeface.font.capHeight, PixelTypeface().glyphHeight, accuracy: 0.05, typeface.id)
        }
    }

    // 폭: 어떤 글꼴이든 픽셀 글꼴과 비슷한 폭 (±15%, 자간을 더 줄이면 글자가 붙음)
    func testWidthsRoughlyMatchPixel() {
        for label in ["CLAUDE", "CODEX"] {
            let target = PixelTypeface().width(of: label)
            for typeface in TypefaceCatalog.all {
                XCTAssertEqual(typeface.width(of: label), target, accuracy: target * 0.15, "\(typeface.id) \(label)")
            }
        }
    }

    func testCRTLeavesGapsBetweenRows() {
        let crt = TextGaugeStyle(typeface: PixelTypeface(style: .scanline))
            .image(for: .init(label: "E", sessionUsed: 1, weeklyUsed: 0, status: .normal))
        let pixel = TextGaugeStyle(typeface: PixelTypeface())
            .image(for: .init(label: "E", sessionUsed: 1, weeklyUsed: 0, status: .normal))
        XCTAssertEqual(crt.size, pixel.size)   // 크기는 같고 모양만 다름
    }
}

final class LockTests: XCTestCase {
    func testLockedUntilPrefersWeekly() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let session = UsageWindow(kind: .session, usedPercent: 100, duration: 18_000, resetsAt: now + 3600)
        let weekly = UsageWindow(kind: .weekly, usedPercent: 100, duration: 604_800, resetsAt: now + 86_400 * 2)
        let descriptor = ProviderDescriptor(id: "c", displayName: "C", menuBarLabel: "C")

        func locked(_ windows: [UsageWindow]) -> Date? {
            let state = ProviderState(snapshot: UsageSnapshot(windows: windows, account: .empty, fetchedAt: now),
                                      lastSuccess: now)
            return MenuBarState(descriptor: descriptor, state: state, now: now).lockedUntil
        }

        XCTAssertEqual(locked([session]), now + 3600)
        XCTAssertEqual(locked([session, weekly]), now + 86_400 * 2)
        let notFull = UsageWindow(kind: .session, usedPercent: 99, duration: 18_000, resetsAt: now + 3600)
        XCTAssertNil(locked([notFull]))
    }

    func testLockedOnlyUntilReset() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let state = MenuBarState(label: "CLAUDE", sessionUsed: 1, weeklyUsed: 0.5, status: .normal, lockedUntil: now + 3600)
        XCTAssertTrue(state.isLocked(now: now))
        XCTAssertFalse(state.isLocked(now: now + 3601))
        XCTAssertFalse(MenuBarState(label: "C", sessionUsed: 0.99, weeklyUsed: 0, status: .normal).isLocked(now: now))
    }
}
