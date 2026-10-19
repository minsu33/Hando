import XCTest
@testable import Hando

@MainActor
final class StatusAnimatorTests: XCTestCase {
    private func spin(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func image(_ typeface: any GaugeTypeface) -> NSImage {
        TextGaugeStyle(typeface: typeface).image(for: .init(label: "CLAUDE", sessionUsed: 1, weeklyUsed: 0.5, status: .normal))
    }

    // 다 찬 상태에서 글꼴을 바꾸면, 움직임이 끝난 뒤에도 새 글꼴이어야 함 (예전엔 옛 글꼴로 돌아감)
    func testKeepsNewTypefaceAfterEffectPlays() {
        let animator = StatusAnimator()
        let button = NSButton()
        let effect = LockEffect.shake   // 0.06초 × 6프레임

        let oldBase = image(PixelTypeface())
        animator.play(effect, frames: Array(repeating: oldBase, count: 6), base: oldBase, on: button)

        let newBase = image(FontTypeface.terminal)
        animator.play(effect, frames: Array(repeating: newBase, count: 6), base: newBase, on: button)

        spin(0.6)
        XCTAssertTrue(button.image === newBase)
        animator.stop(button)
    }

    func testStopRestoresAlpha() {
        let animator = StatusAnimator()
        let button = NSButton()
        animator.blink(button)
        spin(0.7)
        animator.stop(button)
        XCTAssertEqual(button.alphaValue, 1)
    }
}
