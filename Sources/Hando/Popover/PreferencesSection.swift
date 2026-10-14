import SwiftUI

struct PreferencesSection: View {
    @ObservedObject var settings: AppSettings
    let registry: ProviderRegistry
    let label: String
    let onOpenTypefaces: () -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if registry.providers.count > 1 {
                Picker(Strings.Popover.service, selection: providerBinding) {
                    ForEach(registry.descriptors) { Text($0.displayName).tag(Optional($0.id)) }
                }
                .pickerStyle(.segmented)
            }

            typefaceRow

            if LaunchAtLogin.isAvailable {
                Toggle(Strings.Popover.launchAtLogin, isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.callout)
                    .onChange(of: launchAtLogin) { _, wanted in
                        LaunchAtLogin.set(wanted)
                        launchAtLogin = LaunchAtLogin.isEnabled   // 실패하면 원래대로
                    }
            }
        }
    }

    // 누르면 글꼴 페이지로
    private var typefaceRow: some View {
        let current = TypefaceCatalog.typeface(id: settings.typefaceID)
        return Button(action: onOpenTypefaces) {
            HStack(spacing: 8) {
                Text(Strings.Popover.typeface)
                Spacer()
                Image(nsImage: GaugePreview.image(typeface: current, label: label))
                    .renderingMode(.template)
                Text(current.name).foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // 저장된 값이 없으면 지금 보고 있는 서비스로 표시
    private var providerBinding: Binding<String?> {
        Binding(
            get: { settings.providerID ?? registry.resolve(preferredID: nil).descriptor.id },
            set: { settings.providerID = $0 }
        )
    }
}
