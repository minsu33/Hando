import AppKit

/// 메뉴바 아이템 + 팝오버. 뭘 그릴지는 바깥에서 update로 넣어줌
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let animator = StatusAnimator()
    private var unlockTimer: Timer?
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

    func update(state: MenuBarState, style: any MenuBarStyle, lockEffect: LockEffect, accessibilityLabel: String) {
        guard let button = statusItem.button else { return }
        button.setAccessibilityLabel(accessibilityLabel)
        button.toolTip = accessibilityLabel

        button.image = style.image(for: state)
        watchUnlock(state)
        // 로딩, 오류(로그인 필요 등)는 회색으로 깜빡임 / 한도 다 쓰면 몇 초마다 흔들림
        if state.status == .loading || state.status == .error {
            animator.blink(button)
        } else if state.isLocked(now: Date()), let base = button.image {
            let source = FrameSource(image: base, textBottom: style.textBottom, letterCount: state.label.count)
            animator.play(lockEffect, frames: lockEffect.frames(source), base: base, on: button)
        } else {
            animator.stop(button)
        }
    }

    // 리셋 시각이 지나면 흔들림 멈춤 (새 데이터 오기 전이라도)
    private func watchUnlock(_ state: MenuBarState) {
        unlockTimer?.invalidate()
        unlockTimer = nil
        guard let until = state.lockedUntil, until > Date() else { return }
        unlockTimer = Timer.scheduledTimer(withTimeInterval: until.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let button = self.statusItem.button else { return }
                self.animator.stop(button)
            }
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

/// 로딩/오류: 천천히 깜빡임, 한도 다 씀: LockEffect를 몇 초마다 한 번 재생
@MainActor
private final class StatusAnimator {
    private enum Mode: Equatable { case blink, lock(String) }

    private var mode: Mode?
    private var timer: Timer?
    private var frameTimer: Timer?

    static let blinkPeriod: TimeInterval = 1.2
    static let dimAlpha: CGFloat = 0.35

    func play(_ effect: LockEffect, frames: [NSImage], base: NSImage, on button: NSStatusBarButton) {
        guard mode != .lock(effect.id) else { return }
        stop(button)
        mode = .lock(effect.id)
        let run = { [weak self, weak button] in
            guard let self, let button else { return }
            self.runOnce(frames, interval: effect.frameInterval, base: base, on: button)
        }
        run()   // 꽉 찬 순간 바로 한 번
        timer = Timer.scheduledTimer(withTimeInterval: effect.every, repeats: true) { _ in
            MainActor.assumeIsolated { run() }
        }
    }

    private func runOnce(_ frames: [NSImage], interval: TimeInterval, base: NSImage, on button: NSStatusBarButton) {
        frameTimer?.invalidate()
        var index = 0
        frameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self, weak button] t in
            MainActor.assumeIsolated {
                guard let button else { return t.invalidate() }
                if index < frames.count {
                    button.image = frames[index]
                    index += 1
                } else {
                    button.image = base
                    t.invalidate()
                    self?.frameTimer = nil
                }
            }
        }
    }

    func blink(_ button: NSStatusBarButton) {
        guard mode != .blink else { return }
        stop(button)
        mode = .blink
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
        guard mode != nil else { return }
        timer?.invalidate()
        timer = nil
        frameTimer?.invalidate()
        frameTimer = nil
        mode = nil
        button.alphaValue = 1
    }
}
