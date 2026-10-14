import SwiftUI

struct AccountSection: View {
    let account: AccountInfo?
    let commands: AccountCommands?
    let needsLogin: Bool
    var onAction: (AccountCommands.Action) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let account { details(account) }
            if let commands { actions(commands) }
        }
    }

    @ViewBuilder
    private func details(_ account: AccountInfo) -> some View {
        if account.email != nil || account.subscriptionEndsAt != nil {
            VStack(alignment: .leading, spacing: 3) {
                if let email = account.email {
                    Label(email, systemImage: "person.crop.circle")
                }
                if let end = account.subscriptionEndsAt {
                    Label(Strings.Account.subscription(end.formatted(date: .abbreviated, time: .omitted),
                                                       TimeText.dDay(end)),
                          systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func actions(_ commands: AccountCommands) -> some View {
        HStack(spacing: 6) {
            if needsLogin {
                button(Strings.Account.login, commands, .login)
            } else {
                button(Strings.Account.switchAccount, commands, .switchAccount)
                button(Strings.Account.logout, commands, .logout)
            }
            Spacer()
        }
        .controlSize(.small)
        .help(Strings.Account.managedBy(commands.binary))
    }

    private func button(_ title: String, _ commands: AccountCommands, _ action: AccountCommands.Action) -> some View {
        Button(title) {
            onAction(action)
            TerminalLauncher.run(commands.script(for: action), name: commands.binary)
        }
    }
}
