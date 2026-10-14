import Foundation

enum Debug {
    static let isEnabled = ProcessInfo.processInfo.environment["HANDO_DEBUG"] != nil

    static func dump(_ tag: String, status: Int, body: Data) {
        guard isEnabled else { return }
        log("[\(tag)] HTTP \(status)\n\(redact(String(decoding: body, as: UTF8.self)))")
    }

    // stderr라 버퍼링 없이 바로 나감
    static func log(_ message: String) {
        guard isEnabled else { return }
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    // 이메일, 토큰 가리기
    static func redact(_ text: String) -> String {
        // 키 이름으로 먼저 가리고, 나머지는 모양으로
        let keyed = text.replacingOccurrences(
            of: #""(email|user_id|account_id|sub|id)"\s*:\s*"[^"]*""#,
            with: "\"$1\": \"***\"", options: .regularExpression)
        let patterns = [
            #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
            #"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*"#,
            #"[A-Za-z0-9_-]{32,}"#,
            #"user-[A-Za-z0-9]{12,}"#,
        ]
        return patterns.reduce(keyed) {
            $0.replacingOccurrences(of: $1, with: "***", options: .regularExpression)
        }
    }
}
