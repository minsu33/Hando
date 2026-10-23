import Foundation

/// 토큰 만료되면 claude CLI한테 재발급 시킴 (앱은 리프레시 토큰을 안 씀)
protocol ClaudeCLIRefresher: Sendable {
    func refresh() async
}

struct ShellClaudeCLIRefresher: ClaudeCLIRefresher {
    // `claude auth status`는 로컬만 읽어서 갱신 안 됨 (2026-10-23 확인). /status는 계정 상태를 서버에 물어보면서 토큰을 갱신함
    // 디버그용으로 HANDO_CLI_REFRESH 환경변수로 바꿔볼 수 있음
    static let defaultCommand = "claude -p /status"
    var command = ProcessInfo.processInfo.environment["HANDO_CLI_REFRESH"] ?? defaultCommand

    func refresh() async {
        // 아무 프로젝트 폴더도 아닌 임시 폴더에서 (그 폴더 설정을 안 읽게)
        let result = await ShellCommand.run(command, timeout: 30, in: FileManager.default.temporaryDirectory)
        Debug.log("[claude] cli refresh: status \(result.status)\(result.timedOut ? " (timeout)" : "")")
    }
}
