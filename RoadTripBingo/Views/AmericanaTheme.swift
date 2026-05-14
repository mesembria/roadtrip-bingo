import SwiftUI

struct AmericanaTheme {
    static let parchment  = Color(red: 0.969, green: 0.941, blue: 0.890)
    static let paper      = Color(red: 0.929, green: 0.898, blue: 0.816)
    static let ink        = Color(red: 0.110, green: 0.071, blue: 0.035)
    static let green      = Color(red: 0.102, green: 0.361, blue: 0.165)
    static let greenLight = Color(red: 0.176, green: 0.478, blue: 0.243)
    static let yellow     = Color(red: 0.961, green: 0.784, blue: 0.000)
    static let red        = Color(red: 0.753, green: 0.224, blue: 0.169)
    static let shadow     = Color(red: 0.110, green: 0.071, blue: 0.035).opacity(0.18)

    static func rye(_ size: CGFloat) -> Font {
        .custom("Rye-Regular", size: size)
    }
    static func barlowSemiBold(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-SemiBold", size: size)
    }
    static func barlowBold(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-Bold", size: size)
    }

    static func gridBackground() -> some View {
        AmericanaGridBackground()
    }

    private static let tileImageCache = NSCache<NSString, UIImage>()
    private static let iconCache = NSCache<NSString, UIImage>()

    static func tileImage(for square: BingoSquare) -> Image? {
        let key = square.id.uuidString as NSString
        if let cached = tileImageCache.object(forKey: key) {
            return Image(uiImage: cached)
        }
        guard let path = Bundle.main.path(
            forResource: square.id.uuidString,
            ofType: "png",
            inDirectory: "TileImages"
        ), let uiImage = UIImage(contentsOfFile: path) else { return nil }
        tileImageCache.setObject(uiImage, forKey: key)
        return Image(uiImage: uiImage)
    }

    static func icon(named name: String) -> Image? {
        let key = name as NSString
        if let cached = iconCache.object(forKey: key) {
            return Image(uiImage: cached)
        }
        guard let path = Bundle.main.path(
            forResource: name,
            ofType: "png",
            inDirectory: "Icons"
        ), let uiImage = UIImage(contentsOfFile: path) else { return nil }
        let processed = name == "token" ? transparentBackground(from: uiImage) : uiImage
        iconCache.setObject(processed, forKey: key)
        return Image(uiImage: processed)
    }

    // Strips near-white pixels from a PNG so the icon works on any background color.
    private static func transparentBackground(from image: UIImage, threshold: UInt8 = 240) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let w = cgImage.width, h = cgImage.height
        let bytesPerRow = w * 4
        var pixels = [UInt8](repeating: 0, count: h * bytesPerRow)
        guard let ctx = CGContext(
            data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        for i in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[i] >= threshold && pixels[i+1] >= threshold && pixels[i+2] >= threshold {
                pixels[i+3] = 0
            }
        }
        guard let out = ctx.makeImage() else { return image }
        return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
    }

    // Call from a background Task before the board is shown to avoid first-render stall
    static func prewarmTileImages(for squares: [BingoSquare]) {
        for square in squares {
            let key = square.id.uuidString as NSString
            guard tileImageCache.object(forKey: key) == nil else { continue }
            guard let path = Bundle.main.path(
                forResource: square.id.uuidString,
                ofType: "png",
                inDirectory: "TileImages"
            ), let uiImage = UIImage(contentsOfFile: path) else { continue }
            tileImageCache.setObject(uiImage, forKey: key)
        }
    }
}

struct AmericanaGridBackground: View {
    var body: some View {
        AmericanaTheme.parchment
            .overlay(
                Canvas { context, size in
                    let spacing: CGFloat = 28
                    let color = AmericanaTheme.ink.opacity(0.04)
                    var path = Path()
                    var x: CGFloat = 0
                    while x <= size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += spacing
                    }
                    context.stroke(path, with: .color(color), lineWidth: 1)
                }
            )
    }
}
