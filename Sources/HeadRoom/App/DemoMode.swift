import Foundation
import Combine

/// HEADROOM_FAKE=1 이면 메뉴바가 가짜 상태를 3초마다 돌아가면서 보여줌 (디자인 확인용)
enum DemoMode {
    static let isEnabled = ProcessInfo.processInfo.environment["HEADROOM_FAKE"] != nil

    static let samples: [MenuBarState] = [
        .init(label: "CLAUDE", sessionUsed: 0.38, weeklyUsed: 0.5, status: .normal),
        .init(label: "CLAUDE", sessionUsed: 0.81, weeklyUsed: 0.64, status: .normal),
        .init(label: "CLAUDE", sessionUsed: 1, weeklyUsed: 0.7, status: .normal),
        .init(label: "CLAUDE", sessionUsed: 1, weeklyUsed: 1, status: .normal),
        .init(label: "CODEX", sessionUsed: nil, weeklyUsed: 0.3, status: .normal),
        .init(label: "CLAUDE", sessionUsed: nil, weeklyUsed: nil, status: .loading),
        .init(label: "CLAUDE", sessionUsed: nil, weeklyUsed: nil, status: .error),
        .init(label: "CLAUDE", sessionUsed: 0.38, weeklyUsed: 0.5, status: .stale),
    ]

    static func statesIfEnabled(interval: TimeInterval = 3) -> AnyPublisher<MenuBarState, Never>? {
        guard isEnabled else { return nil }
        return Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .scan(0) { i, _ in (i + 1) % samples.count }
            .prepend(0)
            .map { samples[$0] }
            .eraseToAnyPublisher()
    }
}
