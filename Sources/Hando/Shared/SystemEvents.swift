import AppKit
import Network

/// 잠자기에서 깨어남 / 인터넷 다시 연결됨 → onChange
/// 깨어난 직후엔 와이파이가 아직 안 붙었을 수 있어서 조금 기다렸다가 알림
final class SystemEvents {
    private let onChange: () -> Void
    private let wakeDelay: TimeInterval
    private let pathMonitor = NWPathMonitor()
    private var wasOnline = true
    private var wakeObserver: NSObjectProtocol?

    init(wakeDelay: TimeInterval = 3, onChange: @escaping () -> Void) {
        self.onChange = onChange
        self.wakeDelay = wakeDelay

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.wakeDelay) { [weak self] in self?.onChange() }
        }

        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                let online = path.status == .satisfied
                defer { self.wasOnline = online }
                if online && !self.wasOnline { self.onChange() }
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "hando.network"))
    }

    deinit {
        pathMonitor.cancel()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }
}
