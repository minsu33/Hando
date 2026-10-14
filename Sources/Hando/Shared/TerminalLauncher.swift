import AppKit

/// .command 파일 만들어서 터미널 앱으로 실행
enum TerminalLauncher {
    @discardableResult
    static func run(_ script: String, name: String) -> Bool {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hando-\(name)-\(UUID().uuidString.prefix(8)).command")
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        } catch {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
