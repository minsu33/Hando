import Foundation
import Combine

/// 새로고침 타이밍:
/// - 평소엔 interval(기본 2분)마다. 켤 때 마지막 값이 그보다 최근이면 남은 시간만큼 기다렸다가
/// - CLI를 쓰는 중이면(activity) 최소 activityGap 간격으로 바로, 루프도 activeInterval로
/// - 429 받으면 Retry-After 또는 지수 백오프 (최대 15분)
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var provider: any UsageProvider
    @Published private(set) var state = ProviderState()

    static let activityGap: TimeInterval = 60
    static let activeInterval: TimeInterval = 60
    static let activeWindow: TimeInterval = 5 * 60
    static let maxBackoff: TimeInterval = 15 * 60

    private let interval: () -> TimeInterval
    private let now: () -> Date
    private let snapshots: SnapshotCache
    private var backoff: TimeInterval = 0
    private var lastAttempt: Date?
    private var lastActivity: Date?
    private var loop: Task<Void, Never>?
    private var pendingActivityRefresh: Task<Void, Never>?

    init(provider: any UsageProvider,
         interval: @escaping () -> TimeInterval,
         snapshots: SnapshotCache = NoSnapshotCache(),
         now: @escaping () -> Date = Date.init) {
        self.provider = provider
        self.interval = interval
        self.snapshots = snapshots
        self.now = now
        restore()
    }

    deinit {
        loop?.cancel()
        pendingActivityRefresh?.cancel()
    }

    func start() {
        loop?.cancel()
        let firstDelay = initialDelay()
        loop = Task { [weak self] in
            if firstDelay > 0 { try? await Task.sleep(for: .seconds(firstDelay)) }
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
        restore()
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

    func refresh(_ context: FetchContext = .background) async {
        guard !state.isRefreshing else { return }
        state.isRefreshing = true
        lastAttempt = now()
        let current = provider

        let result: Result<UsageSnapshot, ProviderError>
        do {
            result = .success(try await current.fetch(context))
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

    /// 마지막 값이 아직 신선하면 그만큼 첫 요청을 미룸
    func initialDelay() -> TimeInterval {
        guard let last = state.lastSuccess else { return 0 }
        return max(0, interval() - now().timeIntervalSince(last))
    }

    private func restore() {
        guard let cached = snapshots.load(providerID: provider.descriptor.id) else { return }
        state.snapshot = cached
        state.lastSuccess = cached.fetchedAt
    }

    private func apply(_ result: Result<UsageSnapshot, ProviderError>) {
        state.isRefreshing = false
        switch result {
        case .success(let snapshot):
            state.snapshot = snapshot
            state.error = nil
            state.lastSuccess = now()
            backoff = 0
            snapshots.save(snapshot, providerID: provider.descriptor.id)
        case .failure(let error):
            state.error = error
            if case .rateLimited(let retryAfter) = error {
                let doubled = min(max(backoff * 2, interval()), Self.maxBackoff)
                backoff = max(retryAfter ?? 0, doubled)
            }
        }
    }
}
