import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings
    let registry: ProviderRegistry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HeaderView(name: store.provider.descriptor.displayName,
                       plan: store.state.snapshot?.account.plan,
                       isRefreshing: store.state.isRefreshing)

            if let error = store.state.error {
                ErrorBanner(message: error.message)
            }

            content

            Divider()
            PreferencesSection(settings: settings, registry: registry,
                               label: store.provider.descriptor.menuBarLabel)
            Divider()
            FooterView(lastUpdated: store.state.lastSuccess) {
                Task { await store.refresh() }
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var needsLogin: Bool {
        switch store.state.error {
        case .notLoggedIn, .unauthorized: return true
        default: return false
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = store.state.snapshot {
            if snapshot.windows.isEmpty {
                Text(Strings.Popover.noWindows).font(.callout).foregroundStyle(.secondary)
            }
            ForEach(snapshot.windows, id: \.kind) { window in
                UsageWindowRow(window: window)
            }
        } else if store.state.error == nil {
            Text(Strings.Popover.loading).foregroundStyle(.secondary)
        }
        AccountSection(account: store.state.snapshot?.account,
                       commands: store.provider.accountCommands,
                       needsLogin: needsLogin)
    }
}

private struct HeaderView: View {
    let name: String
    let plan: String?
    let isRefreshing: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name).font(.title3.bold())
            if let plan {
                Text(plan)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary))
            }
            Spacer()
            if isRefreshing { ProgressView().controlSize(.small) }
        }
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FooterView: View {
    let lastUpdated: Date?
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            if let lastUpdated {
                Text(Strings.Popover.updated(TimeText.clock(lastUpdated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(Strings.Popover.refresh, action: onRefresh)
            Button(Strings.Popover.quit) { NSApp.terminate(nil) }
        }
        .controlSize(.small)
    }
}
