import AppKit

/// 시스템 폰트 기반. 안 쓴 부분은 외곽선만
struct FontTypeface: GaugeTypeface {
    let id: String
    let name: String
    let font: NSFont
    let kern: CGFloat
    var trackAlpha: CGFloat = 0.4
    var strokeWidth: CGFloat = 4   // 폰트 크기 대비 %, 양수 = 외곽선만

    static let terminal = FontTypeface(id: "terminal", name: "터미널",
                                       font: .monospacedSystemFont(ofSize: 12, weight: .heavy), kern: 0.7)
    static let system = FontTypeface(id: "system", name: "시스템",
                                     font: .systemFont(ofSize: 12, weight: .heavy), kern: 1.5)

    func width(of text: String) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return attributed(text, [:]).size().width - kern   // 마지막 글자 뒤 자간 제외
    }

    func drawTrack(_ text: String, at origin: CGPoint) {
        attributed(text, [
            .strokeColor: NSColor.black.withAlphaComponent(trackAlpha),
            .strokeWidth: strokeWidth,
        ]).draw(at: topLeft(origin))
    }

    func drawInk(_ text: String, at origin: CGPoint) {
        attributed(text, [.foregroundColor: NSColor.black]).draw(at: topLeft(origin))
    }

    private func attributed(_ text: String, _ extra: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .kern: kern]
        attrs.merge(extra) { $1 }
        return NSAttributedString(string: text, attributes: attrs)
    }

    // flipped 컨텍스트에서 draw(at:)은 줄의 왼쪽 위 기준
    private func topLeft(_ origin: CGPoint) -> CGPoint {
        CGPoint(x: origin.x, y: origin.y - font.ascender)
    }
}
