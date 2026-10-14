import Foundation

/// 로그인/로그아웃은 각 서비스 CLI가 함. 앱은 터미널 열어서 대신 쳐주기만
struct AccountCommands: Sendable {
    let binary: String          // "codex"
    let login: String           // "codex login"
    let logout: String          // "codex logout"
    let installHint: String     // CLI 없을 때 보여줄 설치 방법

    enum Action { case login, logout, switchAccount }

    func script(for action: Action) -> String {
        let steps: [String]
        switch action {
        case .login: steps = [login]
        case .logout: steps = [logout]
        case .switchAccount: steps = [logout, login]
        }
        return """
        #!/bin/zsh -l
        if ! command -v \(binary) >/dev/null 2>&1; then
          echo "\(binary) 명령어가 없어요. 설치하고 다시 눌러주세요:"
          echo "  \(installHint)"
          exit 1
        fi
        \(steps.joined(separator: " && "))
        echo
        echo "끝났어요. 이 창은 닫아도 돼요."
        """
    }
}
