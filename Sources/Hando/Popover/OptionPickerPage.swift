import SwiftUI

/// 하나 고르는 목록 페이지 (글꼴, 다 찼을 때 효과 …). 항목이 많아져도 스크롤
struct OptionPickerPage<Preview: View>: View {
    struct Option: Identifiable {
        let id: String
        let name: String
    }

    let title: String
    let options: [Option]
    let selectedID: String
    let preview: (Option) -> Preview
    let onSelect: (String) -> Void
    let onBack: () -> Void

    static var maxListHeight: CGFloat { 380 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackButton(action: onBack)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        if index > 0 { Divider().padding(.leading, 24) }
                        row(option)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
            }
            .frame(maxHeight: Self.maxListHeight)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ option: Option) -> some View {
        let isSelected = option.id == selectedID
        return Button { onSelect(option.id) } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                    .opacity(isSelected ? 1 : 0)
                Text(option.name)
                Spacer()
                preview(option)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 메뉴바 아이콘 미리보기 (정지)
enum GaugePreview {
    static let sample = (session: 0.6, weekly: 0.5)

    static func image(typeface: any GaugeTypeface, label: String, full: Bool = false) -> NSImage {
        TextGaugeStyle(typeface: typeface).image(for: MenuBarState(
            label: label, sessionUsed: full ? 1 : sample.session, weeklyUsed: sample.weekly, status: .normal))
    }
}

/// 다 찼을 때 효과 미리보기: 효과를 쉬지 않고 반복 재생
struct LockEffectPreview: View {
    let effect: LockEffect
    let frames: [NSImage]
    let base: NSImage

    static let pause: TimeInterval = 0.8

    init(effect: LockEffect, typeface: any GaugeTypeface, label: String) {
        self.effect = effect
        let style = TextGaugeStyle(typeface: typeface)
        base = GaugePreview.image(typeface: typeface, label: label, full: true)
        frames = effect.frames(FrameSource(image: base, textBottom: style.textBottom, letterCount: label.count))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: effect.frameInterval)) { context in
            Image(nsImage: frame(at: context.date))
                .renderingMode(.template)
        }
    }

    private func frame(at date: Date) -> NSImage {
        let pauseFrames = Int(Self.pause / effect.frameInterval)
        let cycle = frames.count + pauseFrames
        let index = Int(date.timeIntervalSinceReferenceDate / effect.frameInterval) % max(cycle, 1)
        return index < frames.count ? frames[index] : base
    }
}
