import Foundation

// GET chatgpt.com/backend-api/codex/usage 응답
struct CodexUsageResponse: Decodable {
    struct Window: Decodable {
        let usedPercent: Double
        let limitWindowSeconds: Double?
        let resetAfterSeconds: Double?
        let resetAt: Double?
    }
    struct RateLimit: Decodable {
        let primaryWindow: Window?
        let secondaryWindow: Window?
    }

    let planType: String?
    let rateLimit: RateLimit?

    static func decode(_ data: Data) throws -> CodexUsageResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(Self.self, from: data)
        } catch {
            throw ProviderError.invalidResponse
        }
    }

    func snapshot(account: AccountInfo, now: Date) -> UsageSnapshot {
        let windows = [
            rateLimit?.primaryWindow.map { Self.window($0, fallback: .session, now: now) },
            rateLimit?.secondaryWindow.map { Self.window($0, fallback: .weekly, now: now) },
        ].compactMap { $0 }

        var account = account
        if let plan = planType ?? account.plan {
            account.plan = Self.prettyPlan(plan)
        }
        return UsageSnapshot(windows: windows, account: account, fetchedAt: now)
    }

    static func kind(forSeconds seconds: Double?, fallback: WindowKind) -> WindowKind {
        guard let seconds else { return fallback }
        if abs(seconds - 5 * 3600) <= 30 * 60 { return .session }
        if abs(seconds - 7 * 86400) <= 2 * 3600 { return .weekly }
        return .other(seconds: seconds)
    }

    private static func window(_ w: Window, fallback: WindowKind, now: Date) -> UsageWindow {
        let resetsAt = w.resetAt.map { Date(timeIntervalSince1970: $0) }
            ?? w.resetAfterSeconds.map { now.addingTimeInterval($0) }
        return UsageWindow(kind: kind(forSeconds: w.limitWindowSeconds, fallback: fallback),
                           usedPercent: w.usedPercent,
                           duration: w.limitWindowSeconds,
                           resetsAt: resetsAt)
    }

    private static let knownPlans = ["prolite": "Pro Lite", "chatgptplus": "Plus"]

    static func prettyPlan(_ raw: String) -> String {
        knownPlans[raw.lowercased()]
            ?? raw.split(separator: "_").map(\.capitalized).joined(separator: " ")
    }
}
