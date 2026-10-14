import Foundation

/// 스타일이 받는 입력값. 서비스가 뭔지는 모름
struct MenuBarState: Equatable {
    enum Status: Equatable { case normal, loading, error, stale }

    let label: String
    let sessionUsed: Double?    // 0...1, nil = 5시간 창 없는 플랜
    let weeklyUsed: Double?
    let status: Status

    init(label: String, sessionUsed: Double?, weeklyUsed: Double?, status: Status) {
        self.label = label.uppercased()
        self.sessionUsed = sessionUsed.map { min(max($0, 0), 1) }
        self.weeklyUsed = weeklyUsed.map { min(max($0, 0), 1) }
        self.status = status
    }

    init(descriptor: ProviderDescriptor, state: ProviderState, now: Date = Date()) {
        let status: Status
        switch (state.snapshot, state.error) {
        case (nil, nil): status = .loading
        case (nil, _?): status = .error
        case (_?, _): status = state.isStale(now: now) ? .stale : .normal
        }
        self.init(label: descriptor.menuBarLabel,
                  sessionUsed: state.snapshot?.session?.usedFraction,
                  weeklyUsed: state.snapshot?.weekly?.usedFraction,
                  status: status)
    }
}
