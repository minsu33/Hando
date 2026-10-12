import AppKit

/// 메뉴바 아이템 + 팝오버. 뭘 그릴지는 바깥에서 update로 넣어줌
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let blink = BlinkAnimator()
    private let onOpen: () -> Void

    init(content: NSViewController, onOpen: @escaping () -> Void) {
        self.onOpen = onOpen
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = content

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    func update(state: MenuBarState, style: any MenuBarStyle, accessibilityLabel: String) {
        guard let button = statusItem.button else { return }
        button.image = style.image(for: state)
        button.setAccessibilityLabel(accessibilityLabel)
        button.toolTip = accessibilityLabel

        if state.status == .loading {
            blink.start(on: button)
        } else {
            blink.stop(on: button)
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        onOpen()
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

/// 로딩 중일 때 천천히 깜빡임
@MainActor
private final class BlinkAnimator {
    private var timer: Timer?
    private var dimmed = false

    static let period: TimeInterval = 1.2
    static let dimAlpha: CGFloat = 0.35

    func start(on view: NSView) {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.period / 2, repeats: true) { [weak self, weak view] _ in
            MainActor.assumeIsolated {
                guard let self, let view else { return }
                self.dimmed.toggle()
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = Self.period / 2
                    view.animator().alphaValue = self.dimmed ? Self.dimAlpha : 1
                }
            }
        }
    }

    func stop(on view: NSView) {
        timer?.invalidate()
        timer = nil
        dimmed = false
        view.alphaValue = 1
    }
}
