import Foundation
import Combine

/// HANDO_FAKE=1 이면 메뉴바가 가짜 상태를 3초마다 돌아가면서 보여줌 (디자인 확인용)
/// HANDO_FAKE=loading / error / stale 처럼 주면 그 상태만 계속
enum DemoMode {
    private static let value = ProcessInfo.processInfo.environment["HANDO_FAKE"]
    static let isEnabled = value != nil

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
        if let only = samples.first(where: { "\($0.status)" == value }) {
            return Just(only).eraseToAnyPublisher()
        }
        return Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .scan(0) { i, _ in (i + 1) % samples.count }
            .prepend(0)
            .map { samples[$0] }
            .eraseToAnyPublisher()
    }
}
