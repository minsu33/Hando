import Foundation

/// 스타일이 받는 입력값. 서비스가 뭔지는 모름
struct MenuBarState: Equatable {
    enum Status: Equatable { case normal, loading, error, stale }

    let label: String
    let sessionUsed: Double?    // 0...1, nil = 5시간 창 없는 플랜
    let weeklyUsed: Double?
    let status: Status
    /// 한도를 다 써서 막혀 있으면 풀리는 시각 (주간이 다 찼으면 주간 기준)
    let lockedUntil: Date?
    /// 주간을 7일로 나눴을 때 오늘까지 누적 몫 0...1 (잔디에 중간 진하기로 표시)
    let weeklyAllowance: Double?

    init(label: String, sessionUsed: Double?, weeklyUsed: Double?, status: Status,
         lockedUntil: Date? = nil, weeklyAllowance: Double? = nil) {
        self.label = label.uppercased()
        self.sessionUsed = sessionUsed.map { min(max($0, 0), 1) }
        self.weeklyUsed = weeklyUsed.map { min(max($0, 0), 1) }
        self.status = status
        self.lockedUntil = lockedUntil
        self.weeklyAllowance = weeklyAllowance
    }

    func isLocked(now: Date) -> Bool {
        (lockedUntil ?? .distantPast) > now
    }

    init(descriptor: ProviderDescriptor, state: ProviderState, now: Date = Date()) {
        let status: Status
        switch (state.snapshot, state.error) {
        case (nil, nil): status = .loading
        case (nil, _?): status = .error
        case (_?, _): status = state.isStale(now: now) ? .stale : .normal
        }
        let snapshot = state.snapshot
        let locked = Self.lockedWindow(snapshot, now: now)
        self.init(label: descriptor.menuBarLabel,
                  sessionUsed: snapshot?.session?.usedFraction,
                  weeklyUsed: snapshot?.weekly?.usedFraction,
                  status: status,
                  lockedUntil: locked?.resetsAt,
                  weeklyAllowance: snapshot?.weekly.flatMap { DailyAllowance.fraction(for: $0, now: now) })
    }

    private static func lockedWindow(_ snapshot: UsageSnapshot?, now: Date) -> UsageWindow? {
        [snapshot?.weekly, snapshot?.session]
            .compactMap { $0 }
            .first { $0.usedPercent >= 100 && ($0.resetsAt ?? .distantPast) > now }
    }
}
