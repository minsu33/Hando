import AppKit

/// 메뉴바 모양. 새 모양은 이거 하나 구현하면 됨
protocol MenuBarStyle {
    /// isTemplate = true 인 단색 이미지 (라이트/다크 자동)
    func image(for state: MenuBarState) -> NSImage
}
