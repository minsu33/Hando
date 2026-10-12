import AppKit

@main
enum HeadRoomApp {
    @MainActor
    static func main() {
        if PreviewExporter.runIfRequested() { return }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // Dock 아이콘 숨김
        app.run()
    }
}
