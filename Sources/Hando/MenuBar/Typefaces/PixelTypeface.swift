import AppKit

/// 5x7 도트 글꼴. 잔디랑 같은 결로 보이게 직접 그림
///
/// 도트 경계를 화면 픽셀(@2x = 0.5pt)에 맞춰서 반올림함. 그래서 도트 크기가 1.25처럼
/// 애매해도 흐려지지 않고, 굵은 줄/얇은 줄이 번갈아 나옴 (1.5, 1, 1.5, 1, ...)
struct PixelTypeface: GaugeTypeface {
    let id = "pixel"
    let name = "픽셀"
    var dot: CGFloat = 1.25
    var pixelGrid: CGFloat = 0.5
    var trackAlpha: CGFloat = 0.22

    var inkStep: CGFloat? { pixelGrid }

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
            for (row, col) in PixelFont.dots(for: char) {
                CGRect(x: left + edge(col), y: top + edge(row),
                       width: edge(col + 1) - edge(col), height: edge(row + 1) - edge(row)).fill()
            }
        }
    }
}
