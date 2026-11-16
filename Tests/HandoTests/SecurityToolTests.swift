import XCTest
@testable import Hando

/// security 도구 대신 가짜 스크립트로 각 경우 확인
final class SecurityToolTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("hando-sec-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func fake(_ body: String) throws -> String {
        let url = dir.appendingPathComponent("fake-\(UUID()).sh")
        try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url.path
    }

    func testFoundTrimsNewline() throws {
        let exe = try fake(#"echo '{"claudeAiOauth":{"accessToken":"t"}}'"#)
        XCTAssertEqual(Keychain.readViaSecurityTool(service: "x", executable: exe),
                       .found(Data(#"{"claudeAiOauth":{"accessToken":"t"}}"#.utf8)))
    }

    func testNotFound() throws {
        XCTAssertEqual(Keychain.readViaSecurityTool(service: "x", executable: try fake("exit 44")), .notFound)
    }

    // 허용 창 등으로 멈추면 시간 초과 → nil (기존 방식으로 넘어감)
    func testHangFallsBack() throws {
        let start = Date()
        XCTAssertNil(Keychain.readViaSecurityTool(service: "x", timeout: 0.5, executable: try fake("sleep 10")))
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testOtherErrorFallsBack() throws {
        XCTAssertNil(Keychain.readViaSecurityTool(service: "x", executable: try fake("exit 1")))
    }

    func testPassesServiceName() throws {
        let exe = try fake(#"[ "$1" = find-generic-password ] && [ "$2" = -s ] && [ "$3" = "Claude Code-credentials" ] && [ "$4" = -w ] && echo ok"#)
        XCTAssertEqual(Keychain.readViaSecurityTool(service: "Claude Code-credentials", executable: exe), .found(Data("ok".utf8)))
    }
}

final class VersionFlagTests: XCTestCase {
    // brew 링크(/opt/homebrew/bin/hando → Hando.app/Contents/MacOS/Hando)로 실행해도 앱 버전이 나와야 함
    func testResolvesSymlinkToAppBundle() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hando-ver-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let macOS = dir.appendingPathComponent("Hando.app/Contents/MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleShortVersionString": "9.8.7", "CFBundleIdentifier": "test.hando.\(UUID())"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: dir.appendingPathComponent("Hando.app/Contents/Info.plist"))
        let exe = macOS.appendingPathComponent("Hando")
        try Data().write(to: exe)
        let link = dir.appendingPathComponent("hando")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: exe)

        XCTAssertEqual(VersionFlag.version(executable: link.path), "9.8.7")
    }
}
