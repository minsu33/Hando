import AppKit

/// 시스템에 깔린 폰트 기반. 안 쓴 부분은 외곽선만
/// 폰트마다 생김새가 달라서 크기를 픽셀 글꼴에 맞춤:
/// - 높이: 대문자 높이를 픽셀 글꼴과 같게
/// - 폭: 자간을 조절해서 전체 폭을 픽셀 글꼴과 비슷하게
struct FontTypeface: GaugeTypeface {
    let id: String
    let name: String
    let font: NSFont
    var trackAlpha: CGFloat = 0.4
    var strokeWidth: CGFloat = 4   // 폰트 크기 대비 %, 양수 = 외곽선만

    static let reference = PixelTypeface()
    static let kernRange: ClosedRange<CGFloat> = -0.8...3

    init(id: String, name: String, font base: NSFont) {
        self.id = id
        self.name = name
        let size = base.pointSize * Self.reference.glyphHeight / max(base.capHeight, 1)
        font = NSFont(descriptor: base.fontDescriptor, size: size) ?? base
    }

    /// 이름으로 찾고 없으면 시스템 폰트
    init(id: String, name: String, postScriptName: String) {
        let base = NSFont(name: postScriptName, size: 12) ?? .systemFont(ofSize: 12, weight: .heavy)
        self.init(id: id, name: name, font: base)
    }

    static let system = FontTypeface(id: "system", name: "기본", font: .systemFont(ofSize: 12, weight: .heavy))
    static let terminal = FontTypeface(id: "terminal", name: "터미널", font: .monospacedSystemFont(ofSize: 12, weight: .heavy))
    static let poster = FontTypeface(id: "poster", name: "포스터", postScriptName: "Phosphate-Solid")
    static let marker = FontTypeface(id: "marker", name: "마커", postScriptName: "MarkerFelt-Wide")
    static let chalk = FontTypeface(id: "chalk", name: "분필", postScriptName: "Chalkduster")

    func width(of text: String) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return attributed(text, [:]).size().width - kern(for: text)   // 마지막 글자 뒤 자간 제외
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

    /// 픽셀 글꼴 폭에 맞추는 자간 (너무 붙거나 벌어지지 않게 범위 제한)
    func kern(for text: String) -> CGFloat {
        guard text.count > 1 else { return 0 }
        let natural = NSAttributedString(string: text, attributes: [.font: font]).size().width
        let target = Self.reference.width(of: text)
        let kern = (target - natural) / CGFloat(text.count - 1)
        return min(max(kern, Self.kernRange.lowerBound), Self.kernRange.upperBound)
    }

    private func attributed(_ text: String, _ extra: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .kern: kern(for: text)]
        attrs.merge(extra) { $1 }
        return NSAttributedString(string: text, attributes: attrs)
    }

    // flipped 컨텍스트에서 draw(at:)은 줄의 왼쪽 위 기준
    private func topLeft(_ origin: CGPoint) -> CGPoint {
        CGPoint(x: origin.x, y: origin.y - font.ascender)
    }
}
