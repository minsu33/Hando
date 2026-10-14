import Foundation

/// 토큰 만료되면 claude CLI한테 재발급 시킴 (앱은 리프레시 토큰을 안 씀)
protocol ClaudeCLIRefresher: Sendable {
    func refresh() async
}

struct ShellClaudeCLIRefresher: ClaudeCLIRefresher {
    // 사용량 안 쓰고 로그인 상태만 확인하는 명령. 실행하면서 만료된 토큰을 갱신함
    var command = "claude auth status --json"

    func refresh() async {
        let result = await ShellCommand.run(command, timeout: 30)
        Debug.log("[claude] cli refresh: status \(result.status)\(result.timedOut ? " (timeout)" : "")")
    }
}
