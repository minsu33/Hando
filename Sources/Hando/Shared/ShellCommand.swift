import Foundation

/// 로그인 셸(zsh -l)로 명령 실행. 앱은 터미널 PATH를 모르니까 셸한테 맡김
/// command는 코드에 박힌 상수만 넣을 것 (사용자 입력 X)
enum ShellCommand {
    struct Output: Sendable {
        let status: Int32
        let timedOut: Bool
    }

    static func run(_ command: String, timeout: TimeInterval = 30, in directory: URL? = nil) async -> Output {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            if let directory { process.currentDirectoryURL = directory }
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            let finished = Finished()
            process.terminationHandler = { p in
                if finished.mark() { continuation.resume(returning: Output(status: p.terminationStatus, timedOut: false)) }
            }
            do {
                try process.run()
            } catch {
                if finished.mark() { continuation.resume(returning: Output(status: -1, timedOut: false)) }
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard finished.mark() else { return }
                process.terminate()
                continuation.resume(returning: Output(status: -1, timedOut: true))
            }
        }
    }

    /// continuation 두 번 resume 안 되게
    private final class Finished: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func mark() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }
}
