import Foundation
import Combine

/// 새로고침 타이밍:
/// - 평소엔 interval(기본 2분)마다
/// - CLI를 쓰는 중이면(activity) 최소 activityGap 간격으로 바로바로, 루프도 activeInterval로 빨라짐
/// - 429 받으면 백오프
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var provider: any UsageProvider
    @Published private(set) var state = ProviderState()

    static let activityGap: TimeInterval = 15
    static let activeInterval: TimeInterval = 30
    static let activeWindow: TimeInterval = 5 * 60
    static let maxBackoff: TimeInterval = 15 * 60

    private let interval: () -> TimeInterval
    private let now: () -> Date
    private var backoff: TimeInterval = 0
    private var lastAttempt: Date?
    private var lastActivity: Date?
    private var loop: Task<Void, Never>?
    private var pendingActivityRefresh: Task<Void, Never>?

    init(provider: any UsageProvider,
         interval: @escaping () -> TimeInterval,
         now: @escaping () -> Date = Date.init) {
        self.provider = provider
        self.interval = interval
        self.now = now
    }

    deinit {
        loop?.cancel()
        pendingActivityRefresh?.cancel()
    }

    func start() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.nextDelay()))
            }
        }
    }

    func select(_ provider: any UsageProvider) {
        guard provider.descriptor != self.provider.descriptor else { return }
        self.provider = provider
        state = ProviderState()
        backoff = 0
        lastActivity = nil
        start()
    }

    /// CLI 쓰는 게 감지됐을 때. 너무 자주 부르지 않게 activityGap으로 묶음
    func noteActivity() {
        lastActivity = now()
        guard pendingActivityRefresh == nil, backoff == 0 else { return }

        let wait = max(0, Self.activityGap - now().timeIntervalSince(lastAttempt ?? .distantPast))
        pendingActivityRefresh = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard let self, !Task.isCancelled else { return }
            self.pendingActivityRefresh = nil
            await self.refresh()
        }
    }

    func refresh() async {
        guard !state.isRefreshing else { return }
        state.isRefreshing = true
        lastAttempt = now()
        let current = provider

        let result: Result<UsageSnapshot, ProviderError>
        do {
            result = .success(try await current.fetch())
        } catch let error as ProviderError {
            result = .failure(error)
        } catch {
            result = .failure(.network(error.localizedDescription))
        }

        // 기다리는 동안 서비스가 바뀌었으면 버림
        guard current.descriptor == provider.descriptor else { return }
        apply(result)
    }

    func nextDelay() -> TimeInterval {
        let isActive = lastActivity.map { now().timeIntervalSince($0) < Self.activeWindow } ?? false
        let base = isActive ? min(interval(), Self.activeInterval) : interval()
        return max(base, backoff)
    }

    private func apply(_ result: Result<UsageSnapshot, ProviderError>) {
        state.isRefreshing = false
        switch result {
        case .success(let snapshot):
            state.snapshot = snapshot
            state.error = nil
            state.lastSuccess = now()
            backoff = 0
        case .failure(let error):
            state.error = error
            if error == .rateLimited {
                backoff = min(max(backoff * 2, interval()), Self.maxBackoff)
            }
        }
    }
}
