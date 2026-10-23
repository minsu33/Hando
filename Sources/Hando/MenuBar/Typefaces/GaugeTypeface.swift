import AppKit

/// 글자 게이지 글꼴. origin = (왼쪽 x, 기준선 y), 좌표는 위가 0 (flipped)
protocol GaugeTypeface {
    var id: String { get }
    var name: String { get }

    /// 잉크 채울 때 끊는 단위. nil이면 매끄럽게
    var inkStep: CGFloat? { get }

    func width(of text: String) -> CGFloat
    /// 안 쓴 부분 (흐리게)
    func drawTrack(_ text: String, at origin: CGPoint)
    /// 쓴 부분 (진하게). 클리핑은 바깥에서
    func drawInk(_ text: String, at origin: CGPoint)
}

extension GaugeTypeface {
    var inkStep: CGFloat? { nil }
}

enum TypefaceCatalog {
    static let all: [any GaugeTypeface] = [
        FontTypeface.system,
        FontTypeface.terminal,
        PixelTypeface(),
        PixelTypeface(style: .scanline),
        FontTypeface.poster,
        FontTypeface.gauge,
        FontTypeface.typewriter,
    ]

    static let defaultID = "system"   // 처음 설치하면 기본 글꼴. 개성 있는 건 설정에서

    static func typeface(id: String) -> any GaugeTypeface {
        all.first { $0.id == id } ?? all.first { $0.id == defaultID }!
    }
}
