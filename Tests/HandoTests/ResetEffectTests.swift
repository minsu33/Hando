import XCTest
@testable import Hando

final class ResetEffectTests: XCTestCase {
    private func state(_ session: Double?, weekly: Double = 0.5, status: MenuBarState.Status = .normal, label: String = "CLAUDE") -> MenuBarState {
        MenuBarState(label: label, sessionUsed: session, weeklyUsed: weekly, status: status)
    }

    func testResetDetection() {
        XCTAssertTrue(state(0.0).isReset(from: state(0.72)))                 // 5시간 리셋
        XCTAssertTrue(state(0.3, weekly: 0.0).isReset(from: state(0.3, weekly: 0.9)))   // 주간 리셋
        XCTAssertFalse(state(0.0).isReset(from: state(0.1)))                // 조금 쓴 건 리셋 아님
        XCTAssertFalse(state(0.4).isReset(from: state(0.72)))               // 줄긴 했지만 비진 않음
        XCTAssertFalse(state(0.0).isReset(from: state(0.72, status: .loading)))
        XCTAssertFalse(state(0.0, label: "CODEX").isReset(from: state(0.72)))   // 서비스 바뀜은 리셋 아님

        // 5시간 창 없는 플랜: 글자가 주간을 보여줄 때도 감지
        let before = MenuBarState(label: "CODEX", sessionUsed: nil, weeklyUsed: 0.8, status: .normal, lettersShowWeekly: true)
        let after = MenuBarState(label: "CODEX", sessionUsed: nil, weeklyUsed: 0.0, status: .normal, lettersShowWeekly: true)
        XCTAssertTrue(after.isReset(from: before))
    }

    func testSweepFramesEndOnEmptyImage() {
        let style = TextGaugeStyle(typeface: PixelTypeface())
        let full = style.image(for: state(0.72))
        let empty = style.image(for: state(0.0))
        let before = FrameSource(image: full, textBottom: style.textBottom, letterCount: 6)
        let after = FrameSource(image: empty, textBottom: style.textBottom, letterCount: 6)

        let frames = ResetEffect.sweep.frames(before, after)
        XCTAssertEqual(frames.count, 13)
        XCTAssertTrue(frames.allSatisfy { $0.size == full.size && $0.isTemplate })
        XCTAssertTrue(frames.last === empty)

        // 중간 프레임: 잔디는 그대로, 글자 왼쪽(C 획)은 이미 쓸려 나가서 비어 있음
        let mid = frames[8]
        XCTAssertEqual(RenderProbe.alpha(mid, x: 4, y: 16.75), RenderProbe.alpha(empty, x: 4, y: 16.75), accuracy: 0.05)
        XCTAssertLessThan(RenderProbe.alpha(mid, x: 3.25, y: 8.5), 0.5)
    }

    func testCatalogDefault() {
        XCTAssertEqual(ResetEffectCatalog.effect(id: nil).id, "rewind")
        XCTAssertEqual(ResetEffectCatalog.effect(id: "없음").id, "rewind")
        XCTAssertEqual(ResetEffectCatalog.effect(id: "sweep").id, "sweep")
    }
}

@MainActor
final class ResetPlaybackTests: XCTestCase {
    func testPlayOnceEndsOnFinalImage() {
        let animator = StatusAnimator()
        let button = NSButton()
        let style = TextGaugeStyle(typeface: PixelTypeface())
        let a = style.image(for: .init(label: "CLAUDE", sessionUsed: 0.7, weeklyUsed: 0.5, status: .normal))
        let b = style.image(for: .init(label: "CLAUDE", sessionUsed: 0.0, weeklyUsed: 0.5, status: .normal))

        animator.playOnce([a, a, a], interval: 0.02, final: b, on: button)
        XCTAssertTrue(spinUntil { button.image === b })
    }
}

final class RewindEffectTests: XCTestCase {
    func testRewindEmptiesFromTheRight() {
        let style = TextGaugeStyle(typeface: PixelTypeface())
        let full = style.image(for: .init(label: "CLAUDE", sessionUsed: 1, weeklyUsed: 0.5, status: .normal))
        let empty = style.image(for: .init(label: "CLAUDE", sessionUsed: 0, weeklyUsed: 0.5, status: .normal))
        let before = FrameSource(image: full, textBottom: style.textBottom, letterCount: 6)
        let after = FrameSource(image: empty, textBottom: style.textBottom, letterCount: 6)

        let frames = ResetEffect.rewind.frames(before, after)
        XCTAssertEqual(frames.count, 13)
        XCTAssertTrue(frames.last === empty)

        // 반쯤 진행: 왼쪽 C는 아직 차 있고(1.0), 오른쪽 E 획은 이미 비어 있음(0.22)
        let mid = frames[6]
        XCTAssertEqual(RenderProbe.alpha(mid, x: 3.25, y: 8.5), 1, accuracy: 0.05)
        let eLeft = 2.5 + 5 * (6.5 + 1.5) + 0.75
        XCTAssertEqual(RenderProbe.alpha(mid, x: eLeft, y: 8.5), 0.22, accuracy: 0.05)
    }

    func testLockEffectsKeepGrassStill() {
        let style = TextGaugeStyle(typeface: PixelTypeface())
        let base = style.image(for: .init(label: "CLAUDE", sessionUsed: 1, weeklyUsed: 0.5, status: .normal))
        let src = FrameSource(image: base, textBottom: style.textBottom, letterCount: 6)
        let grass = RenderProbe.alpha(base, x: 4, y: 16.75)
        for effect in LockEffectCatalog.all where effect.id != "glitch" {
            for frame in effect.frames(src) {
                XCTAssertEqual(RenderProbe.alpha(frame, x: 4, y: 16.75), grass, accuracy: 0.05, effect.id)
            }
            XCTAssertLessThanOrEqual(Double(effect.frames(src).count) * effect.frameInterval, 1.05, "\(effect.id) 재생 1초 이하")
            XCTAssertGreaterThanOrEqual(effect.every, 6, "\(effect.id) 간격 6초 이상")
        }
    }
}
