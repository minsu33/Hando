import AppKit

/// 원본 이미지 일부를 옮기거나 키워서 새 프레임 만들기. 좌표는 위가 0
struct FrameCanvas {
    private let ctx: CGContext
    private let size: CGSize

    static let scale: CGFloat = 3   // 잘라낼 때 해상도 (2x 화면에서도 또렷하게)

    static func draw(_ size: CGSize, _ body: @escaping (FrameCanvas) -> Void) -> NSImage {
        let image = NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.interpolationQuality = .none
            body(FrameCanvas(ctx: ctx, size: size))
            return true
        }
        image.isTemplate = true
        return image
    }

    /// 원본의 rect 부분을 (dx, dy)만큼 옮겨서 그림
    func place(_ image: NSImage, from rect: CGRect, dx: CGFloat = 0, dy: CGFloat = 0) {
        guard let piece = Self.crop(image, rect) else { return }
        piece.draw(in: rect.offsetBy(dx: dx, dy: dy), from: .zero, operation: .sourceOver,
                   fraction: 1, respectFlipped: true, hints: nil)
    }

    /// 가운데 기준으로 키워서 그림
    func place(_ image: NSImage, scale: CGFloat) {
        let w = size.width * scale, h = size.height * scale
        image.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h),
                   from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    func clear(_ rect: CGRect) {
        ctx.clear(rect)
    }

    private static func crop(_ image: NSImage, _ rect: CGRect) -> NSImage? {
        var proposed = CGRect(origin: .zero, size: CGSize(width: image.size.width * scale, height: image.size.height * scale))
        guard let cg = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else { return nil }
        let k = CGFloat(cg.width) / image.size.width   // 실제로 받은 해상도 기준
        let px = CGRect(x: rect.minX * k, y: rect.minY * k, width: rect.width * k, height: rect.height * k)
            .intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard !px.isEmpty, let cropped = cg.cropping(to: px) else { return nil }
        return NSImage(cgImage: cropped, size: rect.size)
    }
}
