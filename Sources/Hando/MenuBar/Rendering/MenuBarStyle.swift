import AppKit

/// 메뉴바 모양. 새 모양은 이거 하나 구현하면 됨
protocol MenuBarStyle {
    /// isTemplate = true 인 단색 이미지 (라이트/다크 자동)
    func image(for state: MenuBarState) -> NSImage
    /// 이 위쪽이 글자 영역 (움직임 효과가 글자만 움직일 때 씀)
    var textBottom: CGFloat { get }
}
