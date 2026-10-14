import Foundation

enum FlexibleDate {
    // 초 / 밀리초 / ISO8601 다 받음
    static func parse(_ value: Any?) -> Date? {
        switch value {
        case let n as Double: return Date(timeIntervalSince1970: n > 1e12 ? n / 1000 : n)
        case let n as Int: return parse(Double(n))
        case let s as String: return iso(s)
        default: return nil
        }
    }

    static func iso(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
