import XCTest
@testable import Hando

final class LockEffectTests: XCTestCase {
    private let base = TextGaugeStyle(typeface: PixelTypeface())
        .image(for: .init(label: "CLAUDE", sessionUsed: 1, weeklyUsed: 0.5, status: .normal))

    func testCatalog() {
        let ids = LockEffectCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(LockEffectCatalog.effect(id: nil).id, LockEffectCatalog.defaultID)
        XCTAssertEqual(LockEffectCatalog.effect(id: "wave").id, "wave")
    }

    // 모든 효과: 프레임이 있고, 크기가 원본과 같고, 템플릿 이미지(라이트/다크 대응)
    func testFramesKeepSizeAndTemplate() {
        let source = FrameSource(image: base, textBottom: 14.25, letterCount: 6)
        for effect in LockEffectCatalog.all {
            let frames = effect.frames(source)
            XCTAssertFalse(frames.isEmpty, effect.id)
            for frame in frames {
                XCTAssertEqual(frame.size, base.size, effect.id)
                XCTAssertTrue(frame.isTemplate, effect.id)
            }
        }
    }

    // 웨이브는 글자만 움직이고 잔디는 그대로
    func testWaveKeepsGrassStill() {
        let source = FrameSource(image: base, textBottom: 14.25, letterCount: 6)
        let middle = LockEffect.wave.frames(source)[6]
        XCTAssertEqual(RenderProbe.alpha(middle, x: 4, y: 16.75), RenderProbe.alpha(base, x: 4, y: 16.75), accuracy: 0.05)
    }
}
