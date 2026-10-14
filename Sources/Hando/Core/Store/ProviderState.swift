import Foundation

/// 선택된 서비스 하나의 현재 상태. 실패해도 마지막 성공 값은 들고 있음
struct ProviderState: Sendable {
    var snapshot: UsageSnapshot?
    var error: ProviderError?
    var isRefreshing = false
    var lastSuccess: Date?

    static let staleAfter: TimeInterval = 10 * 60

    func isStale(now: Date) -> Bool {
        guard let lastSuccess else { return false }
        return error != nil && now.timeIntervalSince(lastSuccess) > Self.staleAfter
    }
}
