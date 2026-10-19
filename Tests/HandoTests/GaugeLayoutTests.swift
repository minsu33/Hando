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

    func testCellFills() {
        let m = GaugeMetrics.standard
        // 오늘까지 몫 모르면 예전처럼: 쓴 만큼만
        XCTAssertEqual(layout.cellFills(used: 0, allowance: nil).map(\.background), Array(repeating: m.emptyCellAlpha, count: 7))
        XCTAssertEqual(layout.cellFills(used: 1, allowance: nil).map(\.used), Array(repeating: 1, count: 7))

        // 3일째(몫 3/7), 2.5칸 씀 → 0,1 꽉 / 2 반 / 0~2 중간 바탕 / 3~ 흐림
        let fills = layout.cellFills(used: 2.5 / 7, allowance: 3.0 / 7)
        XCTAssertEqual(fills[1], .init(background: m.allowanceCellAlpha, used: 1))
        XCTAssertEqual(fills[2].background, m.allowanceCellAlpha)
        XCTAssertEqual(fills[2].used, 0.5, accuracy: 0.001)
        XCTAssertEqual(fills[3], .init(background: m.emptyCellAlpha, used: 0))

        // 몫보다 많이 쓰면 쓴 칸이 미래 칸까지 넘어감
        let over = layout.cellFills(used: 4.0 / 7, allowance: 2.0 / 7)
        XCTAssertEqual(over[3], .init(background: m.emptyCellAlpha, used: 1))
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
