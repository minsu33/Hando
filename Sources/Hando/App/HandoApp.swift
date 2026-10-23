import AppKit

@main
enum HandoApp {
    @MainActor
    static func main() {
        // 명령줄 모드 (앱 안 띄움)
        if VersionFlag.runIfRequested() || StatusLine.runIfRequested()
            || PreviewExporter.runIfRequested() || IconExporter.runIfRequested() { return }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // Dock 아이콘 숨김
        app.run()
    }
}
