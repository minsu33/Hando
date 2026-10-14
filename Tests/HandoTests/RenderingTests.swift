import XCTest
import AppKit
@testable import Hando

final class RenderingTests: XCTestCase {
    /// (x, y) pt 위치의 alpha (0...1)
    private func alpha(_ image: NSImage, x: CGFloat, y: CGFloat, scale: CGFloat = 2) -> CGFloat {
        let w = Int(image.size.width * scale), h = Int(image.size.height * scale)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        // 비트맵은 위가 0
        return rep.colorAt(x: Int(x * scale), y: Int(y * scale))!.alphaComponent
    }

    private let style = TextGaugeStyle(typeface: PixelTypeface())

    // 'C' 왼쪽 세로획 4번째 줄 도트 가운데: x = 2.5 + 0.75, y = 13 - 9 + 4.5
    private let strokeDot = (x: CGFloat(3.25), y: CGFloat(8.5))

    func testInkFillsWithUsage() {
        let empty = style.image(for: .init(label: "CLAUDE", sessionUsed: 0, weeklyUsed: 0, status: .normal))
        let full = style.image(for: .init(label: "CLAUDE", sessionUsed: 1, weeklyUsed: 0, status: .normal))

        XCTAssertEqual(alpha(empty, x: strokeDot.x, y: strokeDot.y), 0.22, accuracy: 0.02)
        XCTAssertEqual(alpha(full, x: strokeDot.x, y: strokeDot.y), 1, accuracy: 0.02)
    }

    func testGrassFillsWithWeeklyUsage() {
        let cellY: CGFloat = 16.75
        let used = style.image(for: .init(label: "CLAUDE", sessionUsed: 0, weeklyUsed: 1, status: .normal))
        let error = style.image(for: .init(label: "CLAUDE", sessionUsed: 0, weeklyUsed: 1, status: .error))

        XCTAssertEqual(alpha(used, x: 4, y: cellY), 1, accuracy: 0.02)
        XCTAssertEqual(alpha(error, x: 4, y: cellY), 0, accuracy: 0.02)   // 오류면 잔디 숨김
    }

    func testErrorAndLoadingLookTheSame() {
        for status in [MenuBarState.Status.error, .loading] {
            let image = style.image(for: .init(label: "CLAUDE", sessionUsed: nil, weeklyUsed: nil, status: status))
            XCTAssertEqual(alpha(image, x: strokeDot.x, y: strokeDot.y), 0.55, accuracy: 0.03)   // 회색 글자
            XCTAssertEqual(alpha(image, x: 4, y: 16.75), 0, accuracy: 0.02)                       // 잔디 없음
        }
    }

    func testImagesAreTemplates() {
        for typeface in TypefaceCatalog.all {
            let image = TextGaugeStyle(typeface: typeface)
                .image(for: .init(label: "CODEX", sessionUsed: 0.5, weeklyUsed: 0.5, status: .normal))
            XCTAssertTrue(image.isTemplate, typeface.id)
            XCTAssertGreaterThan(image.size.width, 20, typeface.id)
        }
    }
}

final class ProviderErrorTests: XCTestCase {
    func testWhichErrorsNeedAttention() {
        XCTAssertTrue(ProviderError.notLoggedIn(hint: "").needsAttention)
        XCTAssertTrue(ProviderError.needsUserAction(hint: "").needsAttention)
        XCTAssertFalse(ProviderError.rateLimited(retryAfter: nil).needsAttention)
        XCTAssertFalse(ProviderError.network("x").needsAttention)
    }
}
