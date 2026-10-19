import Foundation

/// 주간 한도를 7일로 똑같이 나눴을 때 "오늘까지 쓸 수 있는 몫"
/// 날짜는 달력이 아니라 주간 창 시작(리셋 - 7일)부터 24시간씩
enum DailyAllowance {
    static let days = 7

    /// 오늘 끝날 때까지 누적 몫 (0...1). 리셋 시각을 모르면 nil
    static func fraction(for window: UsageWindow, now: Date = Date()) -> Double? {
        guard let resetsAt = window.resetsAt else { return nil }
        let duration = window.duration ?? 7 * 86_400
        let elapsed = duration - resetsAt.timeIntervalSince(now)
        guard elapsed >= 0, duration > 0 else { return nil }
        let day = min(Int(elapsed / (duration / Double(days))), days - 1)
        return Double(day + 1) / Double(days)
    }

    /// 칸 하나 = 하루. 쓴 비율(칸 안에서 0...1)과 오늘까지 몫 안인지
    struct Cell: Equatable {
        let used: Double
        let inAllowance: Bool
    }

    static func cells(used: Double, allowance: Double?) -> [Cell] {
        let n = Double(days)
        return (0..<days).map { i in
            Cell(used: min(max(used * n - Double(i), 0), 1),
                 inAllowance: allowance.map { Double(i) < $0 * n - 0.001 } ?? false)
        }
    }

    /// 오늘까지 몫에서 남은 % (음수면 그만큼 미리 당겨 씀)
    static func remainingPercent(for window: UsageWindow, now: Date = Date()) -> Double? {
        fraction(for: window, now: now).map { $0 * 100 - window.usedPercent }
    }
}
