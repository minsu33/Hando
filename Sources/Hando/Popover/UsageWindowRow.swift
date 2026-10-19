import SwiftUI

struct UsageWindowRow: View {
    let window: UsageWindow
    var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.kind.title).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(window.usedPercent.rounded()))%")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            if window.kind == .weekly {
                WeekUsageBar(percent: window.usedPercent, allowance: DailyAllowance.fraction(for: window, now: now))
            } else {
                LinearUsageBar(percent: window.usedPercent)
            }

            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(window.resetsAt.map { Strings.Window.resetsAt(TimeText.clock($0, now: now)) } ?? "")
            }
        }
    }

    // "4시간 35분 후 리셋 · 오늘까지 몫 14% 남음"
    private var caption: String? {
        var parts: [String] = []
        if let resetsAt = window.resetsAt { parts.append(Strings.Window.resetsIn(TimeText.until(resetsAt, now: now))) }
        if window.kind == .weekly, let left = DailyAllowance.remainingPercent(for: window, now: now) {
            parts.append(left >= 0 ? Strings.Window.todayLeft(Int(left.rounded()))
                                   : Strings.Window.todayOver(Int((-left).rounded())))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
