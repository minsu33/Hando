import SwiftUI

struct UsageWindowRow: View {
    let window: UsageWindow
    var now = Date()

    static let warnAt: Double = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.kind.title).font(.subheadline.weight(.medium))
                Spacer()
                Text(Strings.Window.used(Int(window.usedPercent.rounded())))
                    .monospacedDigit()
                Text(Strings.Window.remaining(Int(window.remainingPercent.rounded())))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            ProgressView(value: window.usedPercent, total: 100)
                .tint(window.usedPercent >= Self.warnAt ? .orange : .accentColor)

            if let resetsAt = window.resetsAt {
                Text(Strings.Window.resets(TimeText.clock(resetsAt, now: now), TimeText.until(resetsAt, now: now)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension WindowKind {
    var title: String {
        switch self {
        case .session: return Strings.Window.session
        case .weekly: return Strings.Window.weekly
        case .weeklyModel(let name): return Strings.Window.model(name)
        case .other(let seconds): return Strings.Window.other(seconds)
        }
    }
}
