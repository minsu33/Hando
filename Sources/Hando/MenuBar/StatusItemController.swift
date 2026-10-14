import AppKit

/// 메뉴바 아이템 + 팝오버. 뭘 그릴지는 바깥에서 update로 넣어줌
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let animator = StatusAnimator()
    private let onOpen: () -> Void

    init(content: NSViewController, onOpen: @escaping () -> Void) {
        self.onOpen = onOpen
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = content

        statusItem.autosaveName = "Hando"   // Cmd+드래그로 옮긴 위치 기억

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    func update(state: MenuBarState, style: any MenuBarStyle, accessibilityLabel: String) {
        guard let button = statusItem.button else { return }
        button.setAccessibilityLabel(accessibilityLabel)
        button.toolTip = accessibilityLabel

        button.image = style.image(for: state)
        // 로딩, 오류(로그인 필요 등)는 회색으로 깜빡임
        if state.status == .loading || state.status == .error {
            animator.blink(button)
        } else {
            animator.stop(button)
        }
    }

    func showPopover() {
        guard !popover.isShown, let button = statusItem.button else { return }
        open(from: button)
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            open(from: sender)
        }
    }

    private func open(from button: NSStatusBarButton) {
        onOpen()
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

/// 로딩/오류일 때 천천히 깜빡임
@MainActor
private final class StatusAnimator {
    private var timer: Timer?

    static let blinkPeriod: TimeInterval = 1.2
    static let dimAlpha: CGFloat = 0.35

    func blink(_ button: NSStatusBarButton) {
        guard timer == nil else { return }
        var dimmed = false
        timer = Timer.scheduledTimer(withTimeInterval: Self.blinkPeriod / 2, repeats: true) { [weak button] _ in
            MainActor.assumeIsolated {
                guard let button else { return }
                dimmed.toggle()
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = Self.blinkPeriod / 2
                    button.animator().alphaValue = dimmed ? Self.dimAlpha : 1
                }
            }
        }
    }

    func stop(_ button: NSStatusBarButton) {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        button.alphaValue = 1
    }
}
