import Foundation
import Combine

/// HANDO_FAKE=1 이면 메뉴바가 가짜 상태를 3초마다 돌아가면서 보여줌 (디자인 확인용)
/// HANDO_FAKE=locked / weekly / loading / error / stale 처럼 주면 그 상태만 계속, reset 은 찼다↔비었다 반복
/// HANDO_LOCK_FX=wave 처럼 주면 다 찼을 때 효과를 그걸로, HANDO_FAKE_LABEL로 글자 바꾸기 (효과 비교용)
enum DemoMode {
    private static let value = ProcessInfo.processInfo.environment["HANDO_FAKE"]
    static let isEnabled = value != nil
    static let lockEffectOverride = ProcessInfo.processInfo.environment["HANDO_LOCK_FX"]
    static let resetEffectOverride = ProcessInfo.processInfo.environment["HANDO_RESET_FX"]   // rewind / sweep
    private static let labelOverride = ProcessInfo.processInfo.environment["HANDO_FAKE_LABEL"]

    static let samples: [MenuBarState] = [
        .init(label: "CLAUDE", sessionUsed: 0.38, weeklyUsed: 0.4, status: .normal, weeklyAllowance: 4.0 / 7),
        .init(label: "CLAUDE", sessionUsed: 0.81, weeklyUsed: 0.64, status: .normal, weeklyAllowance: 3.0 / 7),
        .init(label: "CLAUDE", sessionUsed: 1, weeklyUsed: 0.7, status: .normal,
              lockedUntil: Date().addingTimeInterval(4 * 3600)),
        .init(label: "CLAUDE", sessionUsed: 1, weeklyUsed: 1, status: .normal,
              lockedUntil: Date().addingTimeInterval(3 * 86_400)),
        .init(label: "CODEX", sessionUsed: nil, weeklyUsed: 0.3, status: .normal),
        .init(label: "CLAUDE", sessionUsed: nil, weeklyUsed: nil, status: .loading),
        .init(label: "CLAUDE", sessionUsed: nil, weeklyUsed: nil, status: .error),
        .init(label: "CLAUDE", sessionUsed: 0.38, weeklyUsed: 0.5, status: .stale),
    ]

    private static func relabel(_ state: MenuBarState) -> MenuBarState {
        guard let labelOverride else { return state }
        return MenuBarState(label: labelOverride, sessionUsed: state.sessionUsed, weeklyUsed: state.weeklyUsed,
                            status: state.status, lockedUntil: state.lockedUntil, weeklyAllowance: state.weeklyAllowance)
    }

    static var named: [String: MenuBarState] {
        [
            "normal": samples[0],
            "locked": samples[2],     // 5시간 다 씀 → 카운트다운
            "weekly": samples[3],     // 주간도 다 씀 → 일 단위
            "loading": samples[5],
            "error": samples[6],
            "stale": samples[7],
        ]
    }

    static func statesIfEnabled(interval: TimeInterval = 3) -> AnyPublisher<MenuBarState, Never>? {
        guard isEnabled else { return nil }
        if let value, let only = named[value] {
            return Just(relabel(only)).eraseToAnyPublisher()
        }
        if value == "reset" {
            let pair = [
                MenuBarState(label: "CLAUDE", sessionUsed: 0.72, weeklyUsed: 0.5, status: .normal, weeklyAllowance: 4.0 / 7),
                MenuBarState(label: "CLAUDE", sessionUsed: 0.0, weeklyUsed: 0.5, status: .normal, weeklyAllowance: 4.0 / 7),
            ]
            return Timer.publish(every: 4, on: .main, in: .common).autoconnect()
                .scan(0) { i, _ in (i + 1) % 2 }
                .prepend(0)
                .map { relabel(pair[$0]) }
                .eraseToAnyPublisher()
        }
        return Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .scan(0) { i, _ in (i + 1) % samples.count }
            .prepend(0)
            .map { samples[$0] }
            .eraseToAnyPublisher()
    }
}
