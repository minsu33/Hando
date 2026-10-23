import AppKit

/// 기본 스타일: 쓸수록 글자에 잉크가 차고, 아래 잔디 7칸이 주간 사용량
/// 한도를 다 쓴 상태는 모양은 그대로, StatusItemController가 몇 초마다 흔들어 줌
struct TextGaugeStyle: MenuBarStyle {
    let typeface: any GaugeTypeface
    var metrics: GaugeMetrics = .standard

    var textBottom: CGFloat { (metrics.baseline + metrics.grassTop) / 2 }

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
        // 로딩·오류: 글자를 회색으로 꽉 채우고 잔디 없음 (깜빡임은 StatusItemController가)
        if state.status == .loading || state.status == .error {
            typeface.drawInk(state.label, at: layout.textOrigin)
            return
        }

        typeface.drawTrack(state.label, at: layout.textOrigin)

        let inkUsed = state.letterUsed ?? 0
        if inkUsed > 0 {
            ctx.saveGState()
            ctx.clip(to: layout.inkRect(used: inkUsed, step: typeface.inkStep))
            typeface.drawInk(state.label, at: layout.textOrigin)
            ctx.restoreGState()
        }

        let fills = layout.cellFills(used: state.weeklyUsed ?? 0, allowance: state.weeklyAllowance)
        for (rect, fill) in zip(layout.cells, fills) {
            let path = NSBezierPath(roundedRect: rect, xRadius: metrics.cellRadius, yRadius: metrics.cellRadius)
            NSColor.black.withAlphaComponent(fill.background).setFill()
            path.fill()
            guard fill.used > 0 else { continue }
            ctx.saveGState()
            path.addClip()
            NSColor.black.setFill()
            CGRect(x: rect.minX, y: rect.minY, width: layout.filledWidth(of: rect, used: fill.used), height: rect.height).fill()
            ctx.restoreGState()
        }
    }


    private static func overallAlpha(_ status: MenuBarState.Status) -> CGFloat {
        switch status {
        case .error, .loading: return 0.55
        case .stale: return 0.6
        case .normal: return 1
        }
    }
}
