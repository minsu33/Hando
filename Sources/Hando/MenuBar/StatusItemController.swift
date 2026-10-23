import AppKit

/// 메뉴바 아이템 + 팝오버. 뭘 그릴지는 바깥에서 update로 넣어줌
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let animator = StatusAnimator()
    private var unlockTimer: Timer?
    private var lastRendered: (state: MenuBarState, image: NSImage)?
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

    func update(state: MenuBarState, style: any MenuBarStyle, lockEffect: LockEffect,
                resetEffect: ResetEffect?, accessibilityLabel: String) {
        guard let button = statusItem.button else { return }
        button.setAccessibilityLabel(accessibilityLabel)
        button.toolTip = accessibilityLabel

        let image = style.image(for: state)
        let previous = lastRendered
        lastRendered = (state, image)
        button.image = image
        watchUnlock(state)

        // 로딩, 오류(로그인 필요 등)는 회색으로 깜빡임 / 한도 다 쓰면 몇 초마다 움직임 / 리셋되면 한 번 쓸려 나감
        if state.status == .loading || state.status == .error {
            animator.blink(button)
        } else if state.isLocked(now: Date()) {
            let source = FrameSource(image: image, textBottom: style.textBottom, letterCount: state.label.count)
            animator.play(lockEffect, frames: lockEffect.frames(source), base: image, on: button)
        } else {
            animator.stop(button)
            if let resetEffect, let previous, state.isReset(from: previous.state) {
                let before = FrameSource(image: previous.image, textBottom: style.textBottom, letterCount: state.label.count)
                let after = FrameSource(image: image, textBottom: style.textBottom, letterCount: state.label.count)
                animator.playOnce(resetEffect.frames(before, after), interval: resetEffect.frameInterval,
                                  final: image, on: button)
            }
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
/// 재생할 프레임은 update 때마다 최신으로 바꿈 (글꼴·사용량이 바뀌어도 옛 그림이 안 나오게)
@MainActor
final class StatusAnimator {
    private enum Mode: Equatable { case blink, lock(String) }

    private var mode: Mode?
    private var timer: Timer?
    private var frameTimer: Timer?
    private var frames: [NSImage] = []
    private var base: NSImage?

    static let blinkPeriod: TimeInterval = 1.2
    static let dimAlpha: CGFloat = 0.35

    func play(_ effect: LockEffect, frames: [NSImage], base: NSImage, on button: NSButton) {
        // 재생 중이던 건 끊고 새 그림으로
        cancelRun()
        self.frames = frames
        self.base = base
        button.image = base
        guard mode != .lock(effect.id) else { return }   // 같은 효과면 주기는 그대로

        stop(button)
        self.frames = frames
        self.base = base
        mode = .lock(effect.id)
        runOnce(interval: effect.frameInterval, on: button)   // 꽉 찬 순간 바로 한 번
        timer = Timer.scheduledTimer(withTimeInterval: effect.every, repeats: true) { [weak self, weak button] _ in
            MainActor.assumeIsolated {
                guard let self, let button else { return }
                self.runOnce(interval: effect.frameInterval, on: button)
            }
        }
    }

    /// 주기 없이 딱 한 번 (리셋 전환). 재생 중 다른 상태가 오면 그쪽이 끊음
    func playOnce(_ frames: [NSImage], interval: TimeInterval, final: NSImage, on button: NSButton) {
        guard mode == nil else { return }
        self.frames = frames
        self.base = final
        runOnce(interval: interval, on: button)
    }

    private func runOnce(interval: TimeInterval, on button: NSButton) {
        cancelRun()
        var index = 0
        frameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self, weak button] t in
            MainActor.assumeIsolated {
                guard let self, let button else { return t.invalidate() }
                if index < self.frames.count {
                    button.image = self.frames[index]
                    index += 1
                } else {
                    button.image = self.base
                    self.cancelRun()
                }
            }
        }
    }

    private func cancelRun() {
        frameTimer?.invalidate()
        frameTimer = nil
    }

    func blink(_ button: NSButton) {
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

    func stop(_ button: NSButton) {
        cancelRun()
        guard mode != nil else { return }
        timer?.invalidate()
        timer = nil
        mode = nil
        frames = []
        base = nil
        button.alphaValue = 1
    }
}
