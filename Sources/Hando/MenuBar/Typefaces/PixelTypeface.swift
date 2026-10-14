import AppKit

/// 5x7 도트 글꼴. 잔디랑 같은 결로 보이게 직접 그림
///
/// 도트 경계를 화면 픽셀(@2x = 0.5pt)에 맞춰서 반올림함. 그래서 도트 크기가 1.25처럼
/// 애매해도 흐려지지 않고, 굵은 줄/얇은 줄이 번갈아 나옴 (1.5, 1, 1.5, 1, ...)
struct PixelTypeface: GaugeTypeface {
    enum Style {
        case square     // 픽셀: 네모 도트
        case scanline   // CRT: 가로로 이어진 줄 + 줄 사이 틈 (옛날 모니터)
    }

    var style = Style.square
    var dot: CGFloat = 1.25
    var pixelGrid: CGFloat = 0.5
    var trackAlpha: CGFloat = 0.22

    var inkStep: CGFloat? { pixelGrid }

    var id: String { style == .square ? "pixel" : "crt" }
    var name: String { style == .square ? "픽셀" : "CRT" }

    /// CRT 줄 사이 틈 (@2x에서 1px)
    static let scanlineGap: CGFloat = 0.5

    func width(of text: String) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let n = CGFloat(text.count)
        return n * glyphWidth + (n - 1) * letterSpacing
    }

    func drawTrack(_ text: String, at origin: CGPoint) {
        NSColor.black.withAlphaComponent(trackAlpha).setFill()
        fillDots(text, at: origin)
    }

    func drawInk(_ text: String, at origin: CGPoint) {
        NSColor.black.setFill()
        fillDots(text, at: origin)
    }

    /// i번째 도트 경계 (픽셀 격자에 스냅)
    func edge(_ i: Int) -> CGFloat {
        (CGFloat(i) * dot / pixelGrid).rounded() * pixelGrid
    }

    var glyphWidth: CGFloat { edge(PixelFont.columns) }
    var glyphHeight: CGFloat { edge(PixelFont.rows) }
    var letterSpacing: CGFloat { (CGFloat(PixelFont.spacing) * dot / pixelGrid).rounded() * pixelGrid }

    private func fillDots(_ text: String, at origin: CGPoint) {
        let top = origin.y - glyphHeight
        let advance = glyphWidth + letterSpacing

        for (i, char) in text.enumerated() {
            let left = origin.x + CGFloat(i) * advance
            let rects = style == .square ? squares(char) : scanlines(char)
            for rect in rects { rect.offsetBy(dx: left, dy: top).fill() }
        }
    }

    private func squares(_ char: Character) -> [CGRect] {
        PixelFont.dots(for: char).map { row, col in
            CGRect(x: edge(col), y: edge(row), width: edge(col + 1) - edge(col), height: edge(row + 1) - edge(row))
        }
    }

    // 한 줄에서 붙어 있는 도트는 하나의 가로 막대로, 줄 아래쪽은 살짝 비움
    private func scanlines(_ char: Character) -> [CGRect] {
        let byRow = Dictionary(grouping: PixelFont.dots(for: char), by: \.row)
        return byRow.flatMap { row, dots -> [CGRect] in
            let cols = dots.map(\.col).sorted()
            var runs: [(start: Int, end: Int)] = []
            for col in cols {
                if let last = runs.last, last.end == col - 1 { runs[runs.count - 1].end = col } else { runs.append((col, col)) }
            }
            let height = edge(row + 1) - edge(row) - Self.scanlineGap
            return runs.map { CGRect(x: edge($0.start), y: edge(row), width: edge($0.end + 1) - edge($0.start), height: height) }
        }
    }
}
