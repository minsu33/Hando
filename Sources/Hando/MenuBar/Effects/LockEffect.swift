import AppKit

/// 한도를 다 썼을 때 몇 초마다 한 번 재생하는 움직임. 모양은 안 바꾸고 프레임만 만듦
/// 새 효과는 여기 하나 추가하고 LockEffectCatalog에 등록
struct LockEffect {
    let id: String
    let name: String
    var every: TimeInterval = 5           // 재생 간격
    var frameInterval: TimeInterval = 0.05
    /// 원본 이미지 → 프레임들 (마지막엔 원본으로 돌아감)
    let frames: (FrameSource) -> [NSImage]
}

/// 효과가 쓰는 원본. 글자 영역(위)과 잔디 영역(아래)을 나눠서 움직일 수 있게
struct FrameSource {
    let image: NSImage
    let textBottom: CGFloat     // 이 위쪽이 글자
    let letterCount: Int

    var size: CGSize { image.size }
    var textRect: CGRect { CGRect(x: 0, y: 0, width: size.width, height: textBottom) }
    var grassRect: CGRect { CGRect(x: 0, y: textBottom, width: size.width, height: size.height - textBottom) }
}

enum LockEffectCatalog {
    static let all: [LockEffect] = [.shake, .wave, .heartbeat, .glitch, .marquee]
    static let defaultID = "wave"

    static func effect(id: String?) -> LockEffect {
        all.first { $0.id == id } ?? all.first { $0.id == defaultID }!
    }
}

extension LockEffect {
    /// 좌우로 도리도리
    static let shake = LockEffect(id: "shake", name: "흔들림", frameInterval: 0.06) { src in
        [-2, 2, -1.5, 1.5, -0.5, 0].map { dx in
            FrameCanvas.draw(src.size) { $0.place(src.image, from: CGRect(origin: .zero, size: src.size), dx: dx) }
        }
    }

    /// 글자가 왼쪽부터 하나씩 톡 튀어 오름
    static let wave = LockEffect(id: "wave", name: "웨이브", frameInterval: 0.04) { src in
        let n = max(src.letterCount, 1)
        let strip = src.size.width / CGFloat(n)
        let steps = n * 3 + 6
        return (0...steps).map { step in
            FrameCanvas.draw(src.size) { canvas in
                canvas.place(src.image, from: src.grassRect)
                for i in 0..<n {
                    let t = Double(step) / 3 - Double(i)          // 글자마다 늦게 출발
                    let lift = t > 0 && t < 2 ? sin(t / 2 * .pi) : 0
                    let rect = CGRect(x: CGFloat(i) * strip, y: 0, width: strip, height: src.textBottom)
                    canvas.place(src.image, from: rect, dy: -2 * CGFloat(lift))
                }
            }
        }
    }

    /// 두-근
    static let heartbeat = LockEffect(id: "heartbeat", name: "두근", every: 4, frameInterval: 0.05) { src in
        [1.06, 1.1, 1.04, 1, 1.05, 1.08, 1.03, 1].map { scale in
            FrameCanvas.draw(src.size) { $0.place(src.image, scale: scale) }
        }
    }

    /// 가로로 찢어졌다 돌아옴
    static let glitch = LockEffect(id: "glitch", name: "글리치", every: 4, frameInterval: 0.05) { src in
        // (밴드 위치 비율, 높이 비율, 밀림) 프레임마다 다르게
        let frames: [[(CGFloat, CGFloat, CGFloat)]] = [
            [(0.1, 0.25, 2), (0.55, 0.2, -1.5)],
            [(0.3, 0.3, -2.5), (0.75, 0.15, 1.5)],
            [(0.05, 0.2, 1), (0.45, 0.25, 2)],
            [],
        ]
        return frames.map { bands in
            FrameCanvas.draw(src.size) { canvas in
                canvas.place(src.image, from: CGRect(origin: .zero, size: src.size))
                for (top, height, dx) in bands {
                    let rect = CGRect(x: 0, y: src.textBottom * top, width: src.size.width, height: src.textBottom * height)
                    canvas.clear(rect)
                    canvas.place(src.image, from: rect, dx: dx)
                }
            }
        }
    }

    /// 글자가 왼쪽으로 한 바퀴 흘러감
    static let marquee = LockEffect(id: "marquee", name: "전광판", every: 6, frameInterval: 0.04) { src in
        let width = src.size.width
        let stepSize: CGFloat = 1.5
        let steps = Int((width / stepSize).rounded(.up))
        return (1...steps).map { step in
            let offset = CGFloat(step) * stepSize
            return FrameCanvas.draw(src.size) { canvas in
                canvas.place(src.image, from: src.grassRect)
                canvas.place(src.image, from: src.textRect, dx: -offset)
                canvas.place(src.image, from: src.textRect, dx: width - offset)
            }
        } + [src.image]
    }
}
