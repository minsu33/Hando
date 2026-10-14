import Foundation

// GET api.anthropic.com/api/oauth/usage 응답. 필드가 자주 늘어나서 느슨하게 읽음
// { "five_hour": { "utilization": 23.0, "resets_at": "..." }, "seven_day": {...}, "seven_day_opus": {...} | null, ... }
enum ClaudeUsageResponse {
    private static let windows: [(key: String, kind: WindowKind, duration: TimeInterval)] = [
        ("five_hour", .session, 5 * 3600),
        ("seven_day", .weekly, 7 * 86400),
        ("seven_day_opus", .weeklyModel("Opus"), 7 * 86400),
        ("seven_day_sonnet", .weeklyModel("Sonnet"), 7 * 86400),
    ]

    static func snapshot(from data: Data, account: AccountInfo, now: Date) throws -> UsageSnapshot {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw ProviderError.invalidResponse
        }
        let parsed = windows.compactMap { entry -> UsageWindow? in
            guard let w = root[entry.key] as? [String: Any],
                  let used = number(w["utilization"]) else { return nil }
            return UsageWindow(kind: entry.kind, usedPercent: used,
                               duration: entry.duration, resetsAt: FlexibleDate.parse(w["resets_at"]))
        }
        return UsageSnapshot(windows: parsed, account: account, fetchedAt: now)
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let n as Double: return n
        case let n as Int: return Double(n)
        case let s as String: return Double(s)
        default: return nil
        }
    }
}
