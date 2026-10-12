import Foundation
import CoreServices

/// 폴더 안(하위 포함) 뭔가 바뀌면 알려줌. FSEvents라 폴더가 커도 가벼움
final class ActivityMonitor {
    private var stream: FSEventStreamRef?
    private let onActivity: () -> Void

    init?(folders: [URL], latency: TimeInterval = 2, onActivity: @escaping () -> Void) {
        let paths = folders.map(\.path).filter { FileManager.default.fileExists(atPath: $0) }
        guard !paths.isEmpty else { return nil }
        self.onActivity = onActivity

        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<ActivityMonitor>.fromOpaque(info).takeUnretainedValue().onActivity()
        }
        guard let stream = FSEventStreamCreate(nil, callback, &context, paths as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                               latency, FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)) else {
            return nil
        }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    deinit {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }
}
