import CoreGraphics

struct GaugeMetrics {
    var height: CGFloat = 22
    var padding: CGFloat = 2.5
    var baseline: CGFloat = 13
    var grassTop: CGFloat = 15.5
    var grassHeight: CGFloat = 2.5
    var cellGap: CGFloat = 1.3
    var cellRadius: CGFloat = 0.8
    var emptyCellAlpha: CGFloat = 0.16
    var allowanceCellAlpha: CGFloat = 0.45   // 오늘까지 몫인데 아직 안 쓴 칸
    var cellCount = 7

    static let standard = GaugeMetrics()
}

/// 글자 게이지 + 잔디 레이아웃 계산 (그리는 건 안 함, 테스트용으로 분리)
struct GaugeLayout {
    let textWidth: CGFloat
    let metrics: GaugeMetrics

    var imageSize: CGSize {
        CGSize(width: (textWidth + metrics.padding * 2).rounded(.up), height: metrics.height)
    }


    var textOrigin: CGPoint {
        CGPoint(x: metrics.padding, y: metrics.baseline)
    }

    /// 잔디 칸. 양 끝이 글자 폭에 딱 맞음
    var cells: [CGRect] {
        let n = CGFloat(metrics.cellCount)
        let width = (textWidth - metrics.cellGap * (n - 1)) / n
        return (0..<metrics.cellCount).map { i in
            CGRect(x: metrics.padding + CGFloat(i) * (width + metrics.cellGap),
                   y: metrics.grassTop,
                   width: width,
                   height: metrics.grassHeight)
        }
    }

    /// used 0...1 → 칸마다 alpha. 경계 칸은 부분만큼
    /// 칸 하나 = 주간의 하루. 바탕은 오늘까지 몫이면 중간, 아니면 흐리게. 쓴 만큼은 왼쪽부터 꽉 채움
    struct CellFill: Equatable {
        let background: CGFloat
        let used: CGFloat   // 칸 안에서 채울 비율 0...1
    }

    func cellFills(used: Double, allowance: Double?) -> [CellFill] {
        DailyAllowance.cells(used: used, allowance: allowance).map {
            CellFill(background: $0.inAllowance ? metrics.allowanceCellAlpha : metrics.emptyCellAlpha, used: CGFloat($0.used))
        }
    }

    /// 잉크 채울 영역. step 있으면 그 단위로 끊음 (픽셀 글꼴은 1pt)
    func inkRect(used: Double, step: CGFloat?) -> CGRect {
        var width = textWidth * CGFloat(used)
        if let step, step > 0 { width = (width / step).rounded() * step }
        return CGRect(x: metrics.padding, y: 0, width: width, height: metrics.height)
    }
}
