import SwiftUI

struct BingoSquareView: View {
    let square: BingoSquare
    let isMarked: Bool
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if square.id == BingoSquare.freeSquareID {
                    freeCell
                } else {
                    regularCell
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: isMarked)
    }

    private var freeCell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AmericanaTheme.green)
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(AmericanaTheme.yellow, lineWidth: 2)
                .padding(2)
            VStack(spacing: 2) {
                tokenImage
                    .frame(width: 44, height: 44)
                Text("FREE")
                    .font(AmericanaTheme.rye(13))
                    .foregroundColor(AmericanaTheme.yellow)
                    .kerning(1)
            }
        }
        .shadow(color: AmericanaTheme.shadow, radius: 2, x: 0, y: 1)
    }

    private var regularCell: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Card background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isHighlighted
                                    ? AmericanaTheme.yellow
                                    : AmericanaTheme.ink.opacity(0.08),
                                lineWidth: isHighlighted ? 3 : 1
                            )
                    )

                VStack(spacing: 0) {
                    // Image area — upper 75%
                    Group {
                        if let img = AmericanaTheme.tileImage(for: square) {
                            img
                                .resizable()
                                .scaledToFit()
                        } else {
                            Text(square.emoji)
                                .font(.system(size: geo.size.width * 0.38))
                        }
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: geo.size.height * 0.75)

                    // Label strip — bottom 25%
                    ZStack {
                        Color.white
                        Rectangle()
                            .fill(AmericanaTheme.ink.opacity(0.08))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        Text(square.text.uppercased())
                            .font(AmericanaTheme.barlowSemiBold(8.5))
                            .foregroundColor(AmericanaTheme.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 2)
                    }
                    .frame(height: geo.size.height * 0.25)
                    .clipShape(
                        RoundedCornerShape(radius: 8, corners: [.bottomLeft, .bottomRight])
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // SPOTTED! overlay
                if isMarked {
                    spottedOverlay
                        .transition(.scale(scale: 0, anchor: .center).combined(with: .opacity))
                }
            }
        }
        .shadow(color: AmericanaTheme.shadow, radius: 2, x: 0, y: 1)
    }

    private var spottedOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.55))
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(AmericanaTheme.red, lineWidth: 2)
                .padding(4)
                .rotationEffect(.degrees(-12))
            Text("SPOTTED!")
                .font(AmericanaTheme.rye(13))
                .foregroundColor(AmericanaTheme.red)
                .rotationEffect(.degrees(-12))
        }
    }

    @ViewBuilder private var tokenImage: some View {
        if let img = AmericanaTheme.icon(named: "token") {
            img.resizable().scaledToFit()
        } else {
            Text("⭐").font(.system(size: 32))
        }
    }
}

// Selective corner rounding — iOS 16 compatible
struct RoundedCornerShape: Shape {
    let radius: CGFloat
    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
