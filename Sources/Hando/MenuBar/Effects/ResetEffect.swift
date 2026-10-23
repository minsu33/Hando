import AppKit

/// 한도가 리셋돼서 글자가 비워질 때 한 번 재생하는 전환. 전(가득) → 후(빈) 두 그림으로 프레임을 만듦
struct ResetEffect {
    let id: String
    let name: String
    var frameInterval: TimeInterval = 0.04
    let frames: (_ before: FrameSource, _ after: FrameSource) -> [NSImage]
}

enum ResetEffectCatalog {
    static let all: [ResetEffect] = [.rewind, .sweep]
    static let defaultID = "rewind"

    static func effect(id: String?) -> ResetEffect {
        all.first { $0.id == id } ?? all.first { $0.id == defaultID }!
    }
}

extension ResetEffect {
    /// 잉크가 오른쪽부터 빠져나감. 채워지던 방향의 정확한 역재생이라 '비워짐'이 바로 읽힘
    static let rewind = ResetEffect(id: "rewind", name: "되감기") { before, after in
        let width = after.size.width
        let steps = 12
        return (1...steps).map { step in
            let keep = (width * CGFloat(steps - step) / CGFloat(steps) * 2).rounded() / 2   // 아직 찬 채로 남는 폭
            return FrameCanvas.draw(after.size) { canvas in
                canvas.place(after.image, from: CGRect(origin: .zero, size: after.size))
                if keep > 0 {
                    canvas.place(before.image, from: CGRect(x: 0, y: 0, width: keep, height: before.textBottom))
                }
            }
        } + [after.image]
    }

    /// 찬 글자가 왼쪽으로 쓸려 나가고, 빈 글자가 오른쪽에서 따라 들어옴. 잔디는 새 그림 그대로
    static let sweep = ResetEffect(id: "sweep", name: "쓸려 나감") { before, after in
        let width = after.size.width
        let steps = 12
        return (1...steps).map { step in
            let t = Double(step) / Double(steps)
            let eased = 1 - pow(1 - t, 3)                       // 빠르게 나갔다가 부드럽게 멈춤
            let offset = (width * CGFloat(eased) * 2).rounded() / 2   // 2x 픽셀 단위
            return FrameCanvas.draw(after.size) { canvas in
                canvas.place(after.image, from: after.grassRect)
                canvas.place(before.image, from: before.textRect, dx: -offset)
                canvas.place(after.image, from: after.textRect, dx: width - offset)
            }
        } + [after.image]
    }
}
