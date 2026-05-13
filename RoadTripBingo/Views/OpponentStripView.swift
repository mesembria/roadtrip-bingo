import SwiftUI

struct OpponentStripView: View {
    let opponentMarked: [String: Set<Int>]
    let tokenBalances: [String: Int]

    var body: some View {
        HStack(spacing: 24) {
            ForEach(opponentMarked.keys.sorted(), id: \.self) { name in
                let marked = opponentMarked[name] ?? []
                let coins = tokenBalances[name]
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(AmericanaTheme.barlowSemiBold(12))
                            .foregroundColor(AmericanaTheme.ink.opacity(0.8))
                        if let coins {
                            HStack(spacing: 2) {
                                if let img = AmericanaTheme.icon(named: "token") {
                                    img.resizable().scaledToFit().frame(width: 14, height: 14)
                                }
                                Text("\(coins)")
                                    .font(AmericanaTheme.barlowSemiBold(11))
                                    .foregroundColor(AmericanaTheme.ink)
                            }
                        }
                    }
                    MiniGridView(markedPositions: marked)
                    Text("\(marked.count) ✓")
                        .font(AmericanaTheme.barlowSemiBold(10))
                        .foregroundColor(AmericanaTheme.ink.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AmericanaTheme.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AmericanaTheme.ink.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct MiniGridView: View {
    let markedPositions: Set<Int>
    private let size: CGFloat = 10
    private let gap: CGFloat = 2

    var body: some View {
        VStack(spacing: gap) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<5, id: \.self) { col in
                        let pos = row * 5 + col
                        RoundedRectangle(cornerRadius: 2)
                            .fill(pos == 12 ? AmericanaTheme.yellow :
                                  markedPositions.contains(pos) ? AmericanaTheme.green :
                                  AmericanaTheme.ink.opacity(0.12))
                            .frame(width: size, height: size)
                    }
                }
            }
        }
    }
}
