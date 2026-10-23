import AppKit

/// 앱 아이콘 만들기: swift run Hando --export-icon Resources
/// "반쯤 찬 H": 5x7 픽셀 H 아래 절반에 잉크, 그 밑에 잔디 7칸 (흑백)
@MainActor
enum IconExporter {
    static let flag = "--export-icon"

    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag) else { return false }
        let dir = URL(fileURLWithPath: i + 1 < args.count ? args[i + 1] : "Resources")
        let iconset = dir.appendingPathComponent("AppIcon.iconset")
        try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

        for size in [16, 32, 128, 256, 512] {
            write(size, to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
            write(size * 2, to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
        }
        print("저장: \(iconset.path)  →  iconutil -c icns \(iconset.path)")
        return true
    }

    private static let paper = NSColor(white: 0.96, alpha: 1)
    private static let ink = NSColor(white: 0.08, alpha: 1)
    private static let track = NSColor(white: 0.08, alpha: 0.16)

    /// 1024 기준으로 그리고 크기에 맞게 줄임
    static func draw(in ctx: CGContext, size: CGFloat) {
        let k = size / 1024
        ctx.scaleBy(x: k, y: k)

        // macOS 아이콘 바탕 (824 정사각, 둥근 모서리)
        let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
        paper.setFill()
        NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185).fill()

        // H: 5x7 도트, 아래 4줄은 잉크
        let dot: CGFloat = 64, gap: CGFloat = 8
        let glyph = PixelFont.glyphs["H"]!
        let glyphWidth = 5 * dot + 4 * gap
        let left = (1024 - glyphWidth) / 2
        let top: CGFloat = 250   // 위에서부터 (flipped 아님 → 변환)
        for (row, line) in glyph.enumerated() {
            for (col, c) in line.enumerated() where c == "#" {
                let rect = CGRect(x: left + CGFloat(col) * (dot + gap),
                                  y: 1024 - top - CGFloat(row + 1) * dot - CGFloat(row) * gap,
                                  width: dot, height: dot)
                (row >= 3 ? ink : track).setFill()
                rect.fill()
            }
        }

        // 잔디 7칸: 3칸 찼고 1칸 오늘 몫, 나머지 흐림
        let cellGap: CGFloat = 14
        let cellWidth = (glyphWidth - cellGap * 6) / 7
        let cellY = 1024 - top - 7 * dot - 6 * gap - 70 - 40
        for i in 0..<7 {
            let rect = CGRect(x: left + CGFloat(i) * (cellWidth + cellGap), y: cellY, width: cellWidth, height: 40)
            (i < 3 ? ink : i == 3 ? NSColor(white: 0.08, alpha: 0.45) : track).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        }
    }

    private static func write(_ pixels: Int, to url: URL) {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw(in: context.cgContext, size: CGFloat(pixels))
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
