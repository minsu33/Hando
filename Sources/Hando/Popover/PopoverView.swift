import SwiftUI

/// 첫 화면은 사용량만. 설정은 ⚙ 뒤로
struct PopoverView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings
    let registry: ProviderRegistry

    private enum Page { case usage, settings, typefaces, lockEffects }
    @State private var page = Page.usage

    var body: some View {
        Group {
            switch page {
            case .usage: usagePage.transition(.move(edge: .leading).combined(with: .opacity))
            case .settings: settingsPage.transition(.opacity)
            case .typefaces: typefacePage.transition(.move(edge: .trailing).combined(with: .opacity))
            case .lockEffects: lockEffectPage.transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(16)
        .frame(width: 300)
        .onDisappear { page = .usage }   // 다시 열면 첫 화면부터
    }

    private var label: String { store.provider.descriptor.menuBarLabel }

    private func go(_ next: Page) {
        withAnimation(.easeOut(duration: 0.18)) { page = next }
    }

    // MARK: - 사용량

    private var usagePage: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let error = store.state.error {
                Label(error.message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let snapshot = store.state.snapshot {
                if snapshot.windows.isEmpty {
                    Text(Strings.Popover.noWindows).font(.callout).foregroundStyle(.secondary)
                }
                ForEach(snapshot.windows, id: \.kind) { UsageWindowRow(window: $0) }
            } else if store.state.error == nil {
                Text(Strings.Popover.loading).font(.callout).foregroundStyle(.secondary)
            }

            if needsLogin, let commands = store.provider.accountCommands {
                Button(Strings.Account.login) {
                    TerminalLauncher.run(commands.script(for: .login), name: commands.binary)
                }
                .controlSize(.small)
            }

            Divider()
            footer
        }
    }

    // 서비스가 여러 개면 이름 자리에 바로 고르기
    private var header: some View {
        HStack(spacing: 8) {
            if registry.providers.count > 1 {
                Picker(Strings.Popover.service, selection: providerBinding) {
                    ForEach(registry.descriptors) { Text($0.displayName).tag(Optional($0.id)) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            } else {
                Text(store.provider.descriptor.displayName).font(.headline)
            }
            if let plan = store.state.snapshot?.account.plan {
                Text(plan)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary))
            }
            Spacer()
            IconButton(systemName: "arrow.clockwise", label: Strings.Popover.refresh,
                       spinning: store.state.isRefreshing) {
                Task { await store.refresh(.userInitiated) }
            }
            IconButton(systemName: "gearshape", label: Strings.Popover.settings) { go(.settings) }
        }
    }

    private var footer: some View {
        HStack {
            if let email = store.state.snapshot?.account.email {
                Text(email).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if let updated = store.state.lastSuccess {
                Text(TimeText.clock(updated)).help(Strings.Popover.updated(TimeText.clock(updated)))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // 저장된 값이 없으면 지금 보고 있는 서비스로 표시
    private var providerBinding: Binding<String?> {
        Binding(
            get: { settings.providerID ?? store.provider.descriptor.id },
            set: { settings.providerID = $0 }
        )
    }

    private var needsLogin: Bool {
        switch store.state.error {
        case .notLoggedIn, .unauthorized: return true
        default: return false
        }
    }

    // MARK: - 설정

    private var settingsPage: some View {
        SettingsPage(settings: settings, label: label,
                     account: store.state.snapshot?.account,
                     accountCommands: store.provider.accountCommands,
                     needsLogin: needsLogin,
                     onAccountAction: { if $0 != .login { store.provider.forgetCachedCredentials() } },
                     onOpenTypefaces: { go(.typefaces) },
                     onOpenLockEffects: { go(.lockEffects) },
                     onBack: { go(.usage) })
    }

    private var typefacePage: some View {
        OptionPickerPage(
            title: Strings.Popover.typeface,
            options: TypefaceCatalog.all.map { .init(id: $0.id, name: $0.name) },
            selectedID: settings.typefaceID,
            preview: { option in
                Image(nsImage: GaugePreview.image(typeface: TypefaceCatalog.typeface(id: option.id), label: label))
                    .renderingMode(.template)
            },
            onSelect: { settings.typefaceID = $0 },
            onBack: { go(.settings) })
    }

    private var lockEffectPage: some View {
        let typeface = TypefaceCatalog.typeface(id: settings.typefaceID)
        return OptionPickerPage(
            title: Strings.Popover.lockEffect,
            options: LockEffectCatalog.all.map { .init(id: $0.id, name: $0.name) },
            selectedID: settings.lockEffectID,
            preview: { option in
                LockEffectPreview(effect: LockEffectCatalog.effect(id: option.id), typeface: typeface, label: label)
            },
            onSelect: { settings.lockEffectID = $0 },
            onBack: { go(.settings) })
    }
}

/// 헤더 오른쪽 작은 아이콘 버튼
private struct IconButton: View {
    let systemName: String
    let label: String
    var spinning = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(spinning ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: spinning)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
