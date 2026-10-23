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
    /// 5시간 창이 없는 플랜이라 글자가 주간을 대신 보여주는 중
    let lettersShowWeekly: Bool

    init(label: String, sessionUsed: Double?, weeklyUsed: Double?, status: Status,
         lockedUntil: Date? = nil, weeklyAllowance: Double? = nil, lettersShowWeekly: Bool = false) {
        self.label = label.uppercased()
        self.sessionUsed = sessionUsed.map { min(max($0, 0), 1) }
        self.weeklyUsed = weeklyUsed.map { min(max($0, 0), 1) }
        self.status = status
        self.lockedUntil = lockedUntil
        self.weeklyAllowance = weeklyAllowance
        self.lettersShowWeekly = lettersShowWeekly
    }

    /// 글자에 채울 비율. 5시간 창이 없으면 주간
    var letterUsed: Double? { sessionUsed ?? (lettersShowWeekly ? weeklyUsed : nil) }

    /// 이전 상태에서 지금 상태로 올 때 한도가 리셋됐는지 (차 있던 게 거의 0으로)
    func isReset(from previous: MenuBarState) -> Bool {
        guard previous.label == label, status == .normal,
              previous.status == .normal || previous.status == .stale else { return false }
        func dropped(_ old: Double?, _ new: Double?) -> Bool {
            guard let old, let new else { return false }
            return old >= 0.15 && new <= 0.05
        }
        return dropped(previous.letterUsed, letterUsed) || dropped(previous.weeklyUsed, weeklyUsed)
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
        // 5시간 창이 아예 없는 플랜(Codex 일시 해제 등)이면 글자가 비어 보이지 않게 주간을 대신 채움
        let noSession = snapshot != nil && snapshot?.session == nil && snapshot?.weekly != nil
        self.init(label: descriptor.menuBarLabel,
                  sessionUsed: snapshot?.session?.usedFraction,
                  weeklyUsed: snapshot?.weekly?.usedFraction,
                  status: status,
                  lockedUntil: locked?.resetsAt,
                  weeklyAllowance: snapshot?.weekly.flatMap { DailyAllowance.fraction(for: $0, now: now) },
                  lettersShowWeekly: noSession)
    }

    private static func lockedWindow(_ snapshot: UsageSnapshot?, now: Date) -> UsageWindow? {
        [snapshot?.weekly, snapshot?.session]
            .compactMap { $0 }
            .first { $0.usedPercent >= 100 && ($0.resetsAt ?? .distantPast) > now }
    }
}
