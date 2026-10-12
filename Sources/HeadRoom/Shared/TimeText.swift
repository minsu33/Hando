import Foundation

enum TimeText {
    /// "1시간 37분", "2일 3시간"
    static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let d = s / 86_400, h = (s % 86_400) / 3_600, m = (s % 3_600) / 60
        if d > 0 { return "\(d)일 \(h)시간" }
        if h > 0 { return "\(h)시간 \(m)분" }
        return "\(max(m, 1))분"
    }

    static func until(_ date: Date, now: Date = Date()) -> String {
        duration(date.timeIntervalSince(now))
    }

    /// 오늘이면 "오후 7:50", 아니면 "10월 15일 (수) 오후 7:50"
    static func clock(_ date: Date, now: Date = Date()) -> String {
        if Calendar.current.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.month().day().weekday(.abbreviated).hour().minute())
    }

    static func dDay(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        return days >= 0 ? "D-\(days)" : Strings.Account.expired
    }
}
