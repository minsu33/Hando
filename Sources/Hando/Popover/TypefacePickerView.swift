import SwiftUI

/// 글꼴 고르는 페이지. 글꼴이 많아져도 스크롤 목록이라 괜찮음
struct TypefacePickerView: View {
    @ObservedObject var settings: AppSettings
    let label: String
    let onBack: () -> Void

    static let maxListHeight: CGFloat = 380

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onBack) {
                Label(Strings.Popover.back, systemImage: "chevron.left")
                    .font(.callout)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)

            Text(Strings.Popover.typeface)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(TypefaceCatalog.all.enumerated()), id: \.element.id) { index, typeface in
                        if index > 0 { Divider().padding(.leading, 24) }
                        TypefaceRow(typeface: typeface, label: label,
                                    isSelected: typeface.id == settings.typefaceID) {
                            settings.typefaceID = typeface.id
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
            }
            .frame(maxHeight: Self.maxListHeight)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct TypefaceRow: View {
    let typeface: any GaugeTypeface
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                    .opacity(isSelected ? 1 : 0)
                Text(typeface.name)
                Spacer()
                Image(nsImage: GaugePreview.image(typeface: typeface, label: label))
                    .renderingMode(.template)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(typeface.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

enum GaugePreview {
    static func image(typeface: any GaugeTypeface, label: String) -> NSImage {
        TextGaugeStyle(typeface: typeface).image(for: MenuBarState(
            label: label, sessionUsed: 0.6, weeklyUsed: 0.5, status: .normal))
    }
}
