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

    static func tileImage(for square: BingoSquare) -> Image? {
        guard let path = Bundle.main.path(
            forResource: square.id.uuidString,
            ofType: "png",
            inDirectory: "TileImages"
        ), let uiImage = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: uiImage)
    }

    static func icon(named name: String) -> Image? {
        guard let path = Bundle.main.path(
            forResource: name,
            ofType: "png",
            inDirectory: "Icons"
        ), let uiImage = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: uiImage)
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
