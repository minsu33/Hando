import SwiftUI

/// 설정 페이지의 계정 칸: 이메일, 구독 기간, CLI로 로그인/계정 바꾸기/로그아웃
struct AccountSection: View {
    let account: AccountInfo?
    let commands: AccountCommands?
    let needsLogin: Bool
    var onAction: (AccountCommands.Action) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let email = account?.email {
                Text(email).font(.callout)
            }
            if let end = account?.subscriptionEndsAt {
                Text(Strings.Account.subscription(end.formatted(date: .abbreviated, time: .omitted), TimeText.dDay(end)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let commands {
                HStack(spacing: 6) {
                    if needsLogin {
                        button(Strings.Account.login, commands, .login)
                    } else {
                        button(Strings.Account.switchAccount, commands, .switchAccount)
                        button(Strings.Account.logout, commands, .logout)
                    }
                }
                .controlSize(.small)
                .help(Strings.Account.managedBy(commands.binary))
            }
        }
    }

    private func button(_ title: String, _ commands: AccountCommands, _ action: AccountCommands.Action) -> some View {
        Button(title) {
            onAction(action)
            TerminalLauncher.run(commands.script(for: action), name: commands.binary)
        }
    }
}
