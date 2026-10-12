import AppKit
import SwiftUI
import Combine

/// 여기서 전부 조립함
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let registry = ProviderRegistry.live
    private let settings = AppSettings()
    private lazy var store = UsageStore(
        provider: registry.resolve(preferredID: settings.providerID),
        interval: { [settings] in settings.refreshInterval }
    )
    private var statusItem: StatusItemController?
    private var credentialWatcher: FileWatcher?
    private var activityMonitor: ActivityMonitor?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let popover = NSHostingController(rootView: PopoverView(store: store, settings: settings, registry: registry))
        popover.sizingOptions = [.preferredContentSize]

        let statusItem = StatusItemController(content: popover) { [weak self] in
            self?.refreshIfOld()
        }
        self.statusItem = statusItem

        bindMenuBar(to: statusItem)
        bindProviderSelection()
        watchCredentials()
        store.start()
    }

    private func bindMenuBar(to statusItem: StatusItemController) {
        let states: AnyPublisher<(MenuBarState, String), Never>
        if let demo = DemoMode.statesIfEnabled() {
            states = demo.map { ($0, $0.label) }.eraseToAnyPublisher()
        } else {
            states = store.$state
                .combineLatest(store.$provider)
                .map { state, provider in
                    let menuState = MenuBarState(descriptor: provider.descriptor, state: state)
                    return (menuState, provider.descriptor.displayName)
                }
                .eraseToAnyPublisher()
        }

        states
            .removeDuplicates { $0.0 == $1.0 && $0.1 == $1.1 }
            .combineLatest(settings.$typefaceID.removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { (pair, typefaceID) in
                let (state, name) = pair
                let style = TextGaugeStyle(typeface: TypefaceCatalog.typeface(id: typefaceID))
                statusItem.update(state: state, style: style, accessibilityLabel: Self.label(for: state, name: name))
            }
            .store(in: &cancellables)
    }

    private func bindProviderSelection() {
        settings.$providerID
            .dropFirst()
            .compactMap { [registry] in registry.provider(id: $0) }
            .sink { [store] in store.select($0) }
            .store(in: &cancellables)
    }

    // CLI로 로그인/로그아웃하면 바로 반영, CLI 쓰는 중이면 사용량도 바로바로
    private func watchCredentials() {
        store.$provider
            .map(\.descriptor)
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                let provider = store.provider
                credentialWatcher = FileWatcher(files: provider.watchedFiles) { [weak self] in
                    guard let self else { return }
                    Task { await self.store.refresh() }
                }
                activityMonitor = ActivityMonitor(folders: provider.activityFolders) { [weak self] in
                    self?.store.noteActivity()
                }
            }
            .store(in: &cancellables)
    }

    // 팝오버 열 때 1분 넘었으면 새로 가져옴
    private func refreshIfOld() {
        let last = store.state.lastSuccess ?? .distantPast
        guard Date().timeIntervalSince(last) > 60 else { return }
        Task { await store.refresh() }
    }

    private static func label(for state: MenuBarState, name: String) -> String {
        switch state.status {
        case .loading: return Strings.Accessibility.loading(name)
        case .error: return Strings.Accessibility.error(name)
        case .normal, .stale:
            return Strings.Accessibility.gauge(name,
                                               session: state.sessionUsed.map { Int(($0 * 100).rounded()) },
                                               weekly: state.weeklyUsed.map { Int(($0 * 100).rounded()) })
        }
    }
}
