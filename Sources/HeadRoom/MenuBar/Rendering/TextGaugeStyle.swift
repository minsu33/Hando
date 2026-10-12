import AppKit

/// 기본 스타일: 쓸수록 글자에 잉크가 차고, 아래 잔디 7칸이 주간 사용량
struct TextGaugeStyle: MenuBarStyle {
    let typeface: any GaugeTypeface
    var metrics: GaugeMetrics = .standard

    func image(for state: MenuBarState) -> NSImage {
        let layout = GaugeLayout(textWidth: typeface.width(of: state.label), metrics: metrics)

        let image = NSImage(size: layout.imageSize, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setAlpha(Self.overallAlpha(state.status))
            draw(state, layout: layout, in: ctx)
            return true
        }
        image.isTemplate = true
        return image
    }

    private func draw(_ state: MenuBarState, layout: GaugeLayout, in ctx: CGContext) {
        typeface.drawTrack(state.label, at: layout.textOrigin)

        let inkUsed = (state.status == .normal || state.status == .stale) ? (state.sessionUsed ?? 0) : 0
        if inkUsed > 0 {
            ctx.saveGState()
            ctx.clip(to: layout.inkRect(used: inkUsed, step: typeface.inkStep))
            typeface.drawInk(state.label, at: layout.textOrigin)
            ctx.restoreGState()
        }

        guard state.status != .error else { return }
        let weekly = state.status == .loading ? 0 : (state.weeklyUsed ?? 0)
        for (rect, alpha) in zip(layout.cells, layout.cellAlphas(used: weekly)) {
            NSColor.black.withAlphaComponent(alpha).setFill()
            NSBezierPath(roundedRect: rect, xRadius: metrics.cellRadius, yRadius: metrics.cellRadius).fill()
        }
    }

    private static func overallAlpha(_ status: MenuBarState.Status) -> CGFloat {
        switch status {
        case .error: return 0.4
        case .stale: return 0.6
        case .normal, .loading: return 1
        }
    }
}
