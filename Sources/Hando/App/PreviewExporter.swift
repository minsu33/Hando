import AppKit
import ImageIO
import UniformTypeIdentifiers

/// README용 이미지 뽑기: swift run Hando --export-previews assets
/// 앱이 실제로 그리는 코드 그대로 씀
@MainActor
enum PreviewExporter {
    static let flag = "--export-previews"

    private static let scale: CGFloat = 4
    private static let light = Palette(bar: NSColor(white: 0.93, alpha: 1), ink: .black, caption: NSColor(white: 0.45, alpha: 1))

    private struct Palette { let bar, ink, caption: NSColor }

    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag) else { return false }
        let dir = URL(fileURLWithPath: i + 1 < args.count ? args[i + 1] : "assets")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let now = Date()
        let pixel = TextGaugeStyle(typeface: PixelTypeface())
        let claude = MenuBarState(label: "CLAUDE", sessionUsed: 0.4, weeklyUsed: 0.45, status: .normal)
        let codex = MenuBarState(label: "CODEX", sessionUsed: 0.65, weeklyUsed: 0.3, status: .normal)

        save(menuBar(pixel.image(for: claude), palette: light), dir, "menubar-claude")
        save(menuBar(pixel.image(for: codex), palette: light), dir, "menubar-codex")

        let full = MenuBarState(label: "CLAUDE", sessionUsed: 1, weeklyUsed: 0.6, status: .normal, lockedUntil: now + 3600)
        let states: [(MenuBarState, String)] = [
            (.init(label: "CLAUDE", sessionUsed: 0.15, weeklyUsed: 0.1, status: .normal), "여유"),
            (.init(label: "CLAUDE", sessionUsed: 0.7, weeklyUsed: 0.45, status: .normal), "쓰는 중"),
            (full, "다 씀"),
            (.init(label: "CLAUDE", sessionUsed: nil, weeklyUsed: nil, status: .error), "로그인 필요"),
        ]
        save(row(states.map { (pixel.image(for: $0.0), $0.1) }, palette: light), dir, "states")

        let typefaces = TypefaceCatalog.all.map { (TextGaugeStyle(typeface: $0).image(for: claude), $0.name) }
        save(row(typefaces, palette: light), dir, "typefaces")

        // 다 찼을 때 웨이브 움짤: 잠깐 멈췄다가 한 번
        let base = pixel.image(for: full)
        let wave = LockEffect.wave
        let frames = wave.frames(FrameSource(image: base, textBottom: pixel.textBottom, letterCount: full.label.count))
        let sequence = Array(repeating: base, count: Int(0.8 / wave.frameInterval)) + frames
        saveGIF(sequence.map { box($0, palette: light) }, delay: wave.frameInterval, dir, "wave")

        print("저장: \(dir.path)")
        return true
    }

    // 메뉴바 한 줄처럼: [게이지] [와이파이] [배터리] 10월 13일 (월) 오후 3:12
    private static func menuBar(_ gauge: NSImage, palette: Palette) -> NSImage {
        let clock = NSAttributedString(string: "10월 13일 (월) 오후 3:12", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: palette.ink,
        ])
        let symbols = ["wifi", "battery.75percent"].compactMap {
            NSImage(systemSymbolName: $0, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        }
        let gap: CGFloat = 14, side: CGFloat = 16
        let width = side * 2 + gauge.size.width + symbols.reduce(0) { $0 + $1.size.width + gap } + gap + clock.size().width
        let size = CGSize(width: width.rounded(.up), height: 26)

        return NSImage(size: size, flipped: true) { rect in
            palette.bar.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
            var x = side
            tinted(gauge, palette.ink).draw(in: CGRect(x: x, y: 2, width: gauge.size.width, height: gauge.size.height))
            x += gauge.size.width + gap
            for symbol in symbols {
                tinted(symbol, palette.ink).draw(in: CGRect(x: x, y: (26 - symbol.size.height) / 2,
                                                            width: symbol.size.width, height: symbol.size.height))
                x += symbol.size.width + gap
            }
            clock.draw(at: CGPoint(x: x, y: (26 - clock.size().height) / 2))
            return true
        }
    }

    // 아이콘 여러 개 + 아래 설명
    private static func row(_ items: [(NSImage, String)], palette: Palette) -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .medium),
                                                    .foregroundColor: palette.caption]
        let cellWidth = items.map { max($0.0.size.width, NSAttributedString(string: $0.1, attributes: attrs).size().width) }
            .max()! + 24
        let size = CGSize(width: cellWidth * CGFloat(items.count), height: 46)

        return NSImage(size: size, flipped: true) { rect in
            palette.bar.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
            for (i, (image, caption)) in items.enumerated() {
                let left = CGFloat(i) * cellWidth
                tinted(image, palette.ink).draw(in: CGRect(x: left + (cellWidth - image.size.width) / 2, y: 4,
                                                           width: image.size.width, height: image.size.height))
                let text = NSAttributedString(string: caption, attributes: attrs)
                text.draw(at: CGPoint(x: left + (cellWidth - text.size().width) / 2, y: 28))
            }
            return true
        }
    }

    private static func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }

    // 아이콘 하나만 메뉴바 색 배경에 (GIF용, 모서리 투명 안 되니까 네모)
    private static func box(_ icon: NSImage, palette: Palette) -> NSImage {
        let size = CGSize(width: (icon.size.width + 24).rounded(.up), height: 26)
        return NSImage(size: size, flipped: true) { rect in
            palette.bar.setFill()
            rect.fill()
            tinted(icon, palette.ink).draw(in: CGRect(x: 12, y: 2, width: icon.size.width, height: icon.size.height))
            return true
        }
    }

    private static func bitmap(_ image: NSImage) -> NSBitmapImageRep? {
        let size = image.size
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .none
        image.draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func save(_ image: NSImage, _ dir: URL, _ name: String) {
        try? bitmap(image)?.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
    }

    private static func saveGIF(_ frames: [NSImage], delay: TimeInterval, _ dir: URL, _ name: String) {
        let url = dir.appendingPathComponent("\(name).gif") as CFURL
        guard let dest = CGImageDestinationCreateWithURL(url, UTType.gif.identifier as CFString, frames.count, nil) else { return }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary
        for frame in frames {
            if let cg = bitmap(frame)?.cgImage { CGImageDestinationAddImage(dest, cg, frameProps) }
        }
        CGImageDestinationFinalize(dest)
    }
}
