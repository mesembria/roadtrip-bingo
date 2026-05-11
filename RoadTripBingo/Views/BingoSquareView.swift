import SwiftUI

struct BingoSquareView: View {
    let square: BingoSquare
    let isMarked: Bool
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isHighlighted ? Color.yellow : Color.clear, lineWidth: 3)
                    )
                VStack(spacing: 4) {
                    if square.id == BingoSquare.freeSquareID {
                        Text("⭐").font(.system(size: 28))
                        Text("FREE").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.black)
                    } else if isMarked {
                        Text("✓").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                        Text(square.text)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85)).multilineTextAlignment(.center).lineLimit(2)
                    } else {
                        Text(square.emoji).font(.system(size: 24))
                        Text(square.text)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary).multilineTextAlignment(.center).lineLimit(2)
                    }
                }.padding(4)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isMarked && square.id != BingoSquare.freeSquareID ? 0.95 : 1.0)
        .animation(.spring(response: 0.2), value: isMarked)
    }

    private var backgroundColor: Color {
        if square.id == BingoSquare.freeSquareID { return .yellow }
        if isHighlighted { return Color.yellow.opacity(0.3) }
        if isMarked { return .blue }
        return Color.white.opacity(0.08)
    }
}
