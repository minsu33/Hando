import SwiftUI

/// ⚙ 눌렀을 때. 가끔 바꾸는 것들 (모양, 자동 실행, 계정, 종료)
struct SettingsPage: View {
    @ObservedObject var settings: AppSettings
    let label: String
    let account: AccountInfo?
    let accountCommands: AccountCommands?
    let needsLogin: Bool
    let onAccountAction: (AccountCommands.Action) -> Void
    let onOpenTypefaces: () -> Void
    let onOpenLockEffects: () -> Void
    let onBack: () -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BackButton(action: onBack)

            VStack(spacing: 10) {
                typefaceRow
                lockEffectRow
                Toggle(Strings.Popover.resetMotion, isOn: $settings.resetMotion)
                    .toggleStyle(.checkbox)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if LaunchAtLogin.isAvailable {
                    Toggle(Strings.Popover.launchAtLogin, isOn: $launchAtLogin)
                        .toggleStyle(.checkbox)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: launchAtLogin) { _, wanted in
                            LaunchAtLogin.set(wanted)
                            launchAtLogin = LaunchAtLogin.isEnabled   // 실패하면 원래대로
                        }
                }
            }
            .font(.callout)

            Divider()

            AccountSection(account: account, commands: accountCommands,
                           needsLogin: needsLogin, onAction: onAccountAction)

            Divider()

            Button(Strings.Popover.quit) { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var typefaceRow: some View {
        let current = TypefaceCatalog.typeface(id: settings.typefaceID)
        return NavigationRow(title: Strings.Popover.typeface, value: current.name, action: onOpenTypefaces) {
            Image(nsImage: GaugePreview.image(typeface: current, label: label))
                .renderingMode(.template)
        }
    }

    private var lockEffectRow: some View {
        NavigationRow(title: Strings.Popover.lockEffect,
                      value: LockEffectCatalog.effect(id: settings.lockEffectID).name,
                      action: onOpenLockEffects) { EmptyView() }
    }

}

/// "제목 ……… 값 ›" 한 줄
struct NavigationRow<Accessory: View>: View {
    let title: String
    let value: String
    let action: () -> Void
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                Spacer()
                accessory()
                Text(value).foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(Strings.Popover.back, systemImage: "chevron.left")
                .font(.callout)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
    }
}
