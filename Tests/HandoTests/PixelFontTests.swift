import XCTest
@testable import Hando

final class PixelFontTests: XCTestCase {
    func testEveryGlyphIs5x7() {
        for (char, rows) in PixelFont.glyphs {
            XCTAssertEqual(rows.count, PixelFont.rows, "\(char)")
            for row in rows {
                XCTAssertEqual(row.count, PixelFont.columns, "\(char)")
                XCTAssertTrue(row.allSatisfy { $0 == "#" || $0 == "." }, "\(char)")
            }
        }
    }

    func testCoversAlphabetAndDigits() {
        let needed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        XCTAssertTrue(needed.isSubset(of: PixelFont.supported))
    }

    func testLowercaseAndUnknownFallback() {
        XCTAssertEqual(PixelFont.dots(for: "a").count, PixelFont.dots(for: "A").count)
        XCTAssertEqual(PixelFont.dots(for: "가").count, PixelFont.dots(for: "?").count)
    }

    func testWidth() {
        // CLAUDE: 6글자 × 6.5 + 간격 1.5 × 5
        XCTAssertEqual(PixelTypeface().width(of: "CLAUDE"), 46.5)
    }

    func testDotEdgesSnapToPixelGrid() {
        let t = PixelTypeface()
        let edges = (0...7).map(t.edge)
        XCTAssertEqual(edges, [0, 1.5, 2.5, 4, 5, 6.5, 7.5, 9])
        XCTAssertTrue(edges.allSatisfy { ($0 * 2).rounded() == $0 * 2 })
        XCTAssertEqual(t.glyphHeight, 9)
        XCTAssertEqual(PixelTypeface().width(of: ""), 0)
    }
}
