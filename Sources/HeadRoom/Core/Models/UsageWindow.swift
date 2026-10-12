import Foundation

enum WindowKind: Hashable, Sendable {
    case session                // 5시간 롤링
    case weekly
    case weeklyModel(String)    // 모델별 주간 (ex. Opus)
    case other(seconds: TimeInterval?)
}

struct UsageWindow: Hashable, Sendable {
    let kind: WindowKind
    let usedPercent: Double     // 0...100
    let duration: TimeInterval?
    let resetsAt: Date?

    init(kind: WindowKind, usedPercent: Double, duration: TimeInterval?, resetsAt: Date?) {
        self.kind = kind
        self.usedPercent = min(max(usedPercent, 0), 100)
        self.duration = duration
        self.resetsAt = resetsAt
    }

    var usedFraction: Double { usedPercent / 100 }
    var remainingPercent: Double { 100 - usedPercent }
}
