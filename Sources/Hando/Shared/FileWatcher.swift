import Foundation

/// 파일이 바뀌면 알려줌. CLI는 파일을 통째로 갈아끼우니까 폴더를 보고,
/// 폴더 안 다른 파일 변경은 수정 시각 비교로 걸러냄
final class FileWatcher {
    private let files: [URL]
    private let onChange: () -> Void
    private let debounce: TimeInterval
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?
    private var lastSeen: [URL: Date?]

    init(files: [URL], debounce: TimeInterval = 0.5, onChange: @escaping () -> Void) {
        self.files = files
        self.onChange = onChange
        self.debounce = debounce
        lastSeen = Dictionary(uniqueKeysWithValues: files.map { ($0, Self.modified($0)) })
        let folders = Set(files.map { $0.deletingLastPathComponent().path })
        sources = folders.compactMap(watch)
    }

    deinit { sources.forEach { $0.cancel() } }

    private func watch(_ path: String) -> DispatchSourceFileSystemObject? {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return nil }   // 폴더 없으면 패스 (주기 새로고침이 잡아줌)
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
                                                               eventMask: [.write, .rename, .delete],
                                                               queue: .main)
        source.setEventHandler { [weak self] in self?.schedule() }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }

    private func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.checkForChanges() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    private func checkForChanges() {
        let now = Dictionary(uniqueKeysWithValues: files.map { ($0, Self.modified($0)) })
        guard now != lastSeen else { return }
        lastSeen = now
        onChange()
    }

    private static func modified(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
