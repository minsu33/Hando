import XCTest
@testable import Hando

final class GaugeLayoutTests: XCTestCase {
    private let layout = GaugeLayout(textWidth: 35, metrics: .standard)

    func testCellsSpanTextWidthExactly() {
        let cells = layout.cells
        XCTAssertEqual(cells.count, 7)
        XCTAssertEqual(cells.first!.minX, layout.textOrigin.x, accuracy: 0.001)
        XCTAssertEqual(cells.last!.maxX, layout.textOrigin.x + 35, accuracy: 0.001)
    }

    func testCellAlphas() {
        let m = GaugeMetrics.standard
        XCTAssertEqual(layout.cellAlphas(used: 0), Array(repeating: m.emptyCellAlpha, count: 7))
        XCTAssertEqual(layout.cellAlphas(used: 1), Array(repeating: 1, count: 7))

        // 50% → 3칸 꽉, 4번째 반
        let half = layout.cellAlphas(used: 0.5)
        XCTAssertEqual(half[2], 1)
        XCTAssertEqual(half[3], m.emptyCellAlpha + (1 - m.emptyCellAlpha) * 0.5, accuracy: 0.001)
        XCTAssertEqual(half[4], m.emptyCellAlpha)
    }

    func testInkSnapsToStep() {
        XCTAssertEqual(layout.inkRect(used: 0.5, step: nil).width, 17.5, accuracy: 0.001)
        XCTAssertEqual(layout.inkRect(used: 0.5, step: 1).width, 18)   // 17.5 → 반올림
        XCTAssertEqual(layout.inkRect(used: 0.01, step: 1).width, 0)
    }

    func testImageSizeIsWholePoints() {
        let size = GaugeLayout(textWidth: 33.3, metrics: .standard).imageSize
        XCTAssertEqual(size.width, 39)
        XCTAssertEqual(size.height, 22)
    }
}
