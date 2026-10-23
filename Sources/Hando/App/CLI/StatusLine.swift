import Foundation

/// `hando --statusline [claude|codex]` → 터미널 한 줄. 예: `CLAUDE 5h 42% ▓▓▓▒░░░`
/// 키체인·네트워크는 절대 안 건드림 (Claude Code가 자주 부름). 값은
/// 1) stdin에 Claude Code가 넘겨준 rate_limits가 있으면 그거
/// 2) 없으면 앱이 저장해둔 마지막 값 (오래됐으면 "· N분 전")
enum StatusLine {
    static let flag = "--statusline"
    static let staleAfter: TimeInterval = 3 * 60
    static let appDefaultsSuite = "io.github.minsu33.hando"

    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag) else { return false }
        let requested = i + 1 < args.count && !args[i + 1].hasPrefix("-") ? args[i + 1] : nil

        let stdin = readStdinIfPiped()
        let line: String
        if let stdin, let snapshot = parseClaudeCode(stdin) {
            line = render(label: "CLAUDE", snapshot: snapshot, now: Date(), fromCache: false)
        } else {
            let id = requested ?? UserDefaults(suiteName: appDefaultsSuite)?.string(forKey: "providerID") ?? "claude"
            let snapshot = FileSnapshotCache().load(providerID: id)
            line = render(label: id.uppercased(), snapshot: snapshot, now: Date(), fromCache: true)
        }
        print(line)
        return true
    }

    // MARK: - 순수 함수 (테스트용)

    static func render(label: String, snapshot: UsageSnapshot?, now: Date, fromCache: Bool) -> String {
        guard let snapshot, let main = snapshot.session ?? snapshot.weekly else { return "\(label) —" }
        let scope = snapshot.session != nil ? "5h" : "주"
        var parts = [label, scope, "\(Int(main.usedPercent.rounded()))%"]

        if let weekly = snapshot.weekly {
            let cells = DailyAllowance.cells(used: weekly.usedFraction, allowance: DailyAllowance.fraction(for: weekly, now: now))
            parts.append(String(cells.map { $0.used >= 0.5 ? "▓" : ($0.inAllowance ? "▒" : "░") }))
        }
        var line = parts.joined(separator: " ")
        let age = now.timeIntervalSince(snapshot.fetchedAt)
        if fromCache, age > staleAfter {
            line += " · \(TimeText.duration(age)) 전"
        }
        return line
    }

    /// Claude Code 상태줄 입력의 rate_limits (Pro/Max, 세션 첫 응답 뒤부터 들어옴)
    static func parseClaudeCode(_ data: Data, now: Date = Date()) -> UsageSnapshot? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let limits = root["rate_limits"] as? [String: Any] else { return nil }

        func window(_ key: String, _ kind: WindowKind, _ duration: TimeInterval) -> UsageWindow? {
            guard let w = limits[key] as? [String: Any],
                  let used = number(w["used_percentage"]) ?? number(w["utilization"]) else { return nil }
            return UsageWindow(kind: kind, usedPercent: used, duration: duration, resetsAt: FlexibleDate.parse(w["resets_at"]))
        }
        let windows = [window("five_hour", .session, 5 * 3600), window("seven_day", .weekly, 7 * 86_400)].compactMap { $0 }
        return windows.isEmpty ? nil : UsageSnapshot(windows: windows, account: .empty, fetchedAt: now)
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let n as Double: return n
        case let n as Int: return Double(n)
        case let s as String: return Double(s)
        default: return nil
        }
    }

    private static func readStdinIfPiped() -> Data? {
        guard isatty(FileHandle.standardInput.fileDescriptor) == 0 else { return nil }
        let data = FileHandle.standardInput.readDataToEndOfFile()
        return data.isEmpty ? nil : data
    }
}

/// `hando --version`
enum VersionFlag {
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--version") else { return false }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        print("Hando \(version)")
        return true
    }
}
