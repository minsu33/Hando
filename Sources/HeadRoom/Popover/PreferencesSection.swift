import SwiftUI

struct PreferencesSection: View {
    @ObservedObject var settings: AppSettings
    let registry: ProviderRegistry
    let label: String

    @State private var showsTypefaces = false
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
            if showsTypefaces { typefaceGrid }

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

    // 접혀 있을 땐 지금 글꼴만, 누르면 펼쳐짐
    private var typefaceRow: some View {
        let current = TypefaceCatalog.typeface(id: settings.typefaceID)
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { showsTypefaces.toggle() }
        } label: {
            HStack(spacing: 8) {
                Text(Strings.Popover.typeface)
                Spacer()
                Image(nsImage: GaugePreview.image(typeface: current, label: label))
                    .renderingMode(.template)
                Text(current.name).foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showsTypefaces ? 180 : 0))
            }
            .font(.callout)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var typefaceGrid: some View {
        HStack(spacing: 8) {
            ForEach(TypefaceCatalog.all, id: \.id) { typeface in
                TypefaceOption(typeface: typeface, label: label,
                               isSelected: typeface.id == settings.typefaceID) {
                    settings.typefaceID = typeface.id
                    withAnimation(.easeOut(duration: 0.15)) { showsTypefaces = false }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // 저장된 값이 없으면 지금 보고 있는 서비스로 표시
    private var providerBinding: Binding<String?> {
        Binding(
            get: { settings.providerID ?? registry.resolve(preferredID: nil).descriptor.id },
            set: { settings.providerID = $0 }
        )
    }
}

private enum GaugePreview {
    static func image(typeface: any GaugeTypeface, label: String) -> NSImage {
        TextGaugeStyle(typeface: typeface).image(for: MenuBarState(
            label: label, sessionUsed: 0.6, weeklyUsed: 0.5, status: .normal))
    }
}

private struct TypefaceOption: View {
    let typeface: any GaugeTypeface
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(nsImage: GaugePreview.image(typeface: typeface, label: label))
                    .renderingMode(.template)
                Text(typeface.name).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                                  lineWidth: isSelected ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(typeface.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
