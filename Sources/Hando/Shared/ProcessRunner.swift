import Foundation

/// 셸 없이 프로그램 하나 실행하고 표준출력 받기 (시간 제한 있음, 출력이 작은 명령용)
enum ProcessRunner {
    struct Output: Sendable {
        let status: Int32
        let stdout: Data
    }

    /// 시간 안에 안 끝나면 끄고 nil
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) -> Output? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        do { try process.run() } catch { return nil }

        // 출력이 작아서(파이프 버퍼 64KB 이하) 끝난 뒤 한 번에 읽어도 됨
        guard done.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            return nil
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return Output(status: process.terminationStatus, stdout: data)
    }
}
