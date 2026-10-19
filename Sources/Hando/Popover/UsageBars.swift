import SwiftUI

/// 팝오버 막대. 메뉴바처럼 단색, 90% 넘으면만 주황
enum UsageBarStyle {
    static let height: CGFloat = 5
    static let warnAt: Double = 90

    static func tint(_ percent: Double) -> Color {
        percent >= warnAt ? .orange : .primary
    }
}

struct LinearUsageBar: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(UsageBarStyle.tint(percent))
                    .frame(width: geo.size.width * percent / 100)
            }
        }
        .frame(height: UsageBarStyle.height)
    }
}

/// 주간: 메뉴바 잔디처럼 7칸. 오늘까지 몫은 중간 회색
struct WeekUsageBar: View {
    let percent: Double
    let allowance: Double?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(DailyAllowance.cells(used: percent / 100, allowance: allowance).enumerated()), id: \.offset) { _, cell in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(cell.inAllowance ? AnyShapeStyle(.secondary.opacity(0.45)) : AnyShapeStyle(.quaternary))
                        Rectangle().fill(UsageBarStyle.tint(percent))
                            .frame(width: geo.size.width * cell.used)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
            }
        }
        .frame(height: UsageBarStyle.height)
    }
}
