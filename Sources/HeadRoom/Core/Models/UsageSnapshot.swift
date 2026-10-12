import Foundation

struct UsageSnapshot: Sendable {
    let windows: [UsageWindow]
    let account: AccountInfo
    let fetchedAt: Date

    func window(_ kind: WindowKind) -> UsageWindow? {
        windows.first { $0.kind == kind }
    }

    var session: UsageWindow? { window(.session) }
    var weekly: UsageWindow? { window(.weekly) }

    /// 5시간/주간 말고 나머지 (모델별 한도 등)
    var extraWindows: [UsageWindow] {
        windows.filter { $0.kind != .session && $0.kind != .weekly }
    }
}
