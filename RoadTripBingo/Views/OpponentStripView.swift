import SwiftUI

struct OpponentStripView: View {
    let opponentBoards: [String: [BingoSquare]]
    let opponentMarked: [String: Set<UUID>]
    let tokenBalances: [String: Int]
    var isVertical: Bool = false

    var body: some View {
        containerStack
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AmericanaTheme.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(AmericanaTheme.ink.opacity(0.10), lineWidth: 1)
                    )
            )
    }

    @ViewBuilder private var containerStack: some View {
        if isVertical {
            VStack(spacing: 12) { opponentCards }
        } else {
            HStack(spacing: 24) { opponentCards }
        }
    }

    @ViewBuilder private var opponentCards: some View {
        ForEach(opponentMarked.keys.sorted(), id: \.self) { name in
            opponentCard(name: name)
        }
    }

    private func opponentCard(name: String) -> some View {
        let markedIDs = opponentMarked[name] ?? []
        let board = opponentBoards[name] ?? []
        let markedPositions: Set<Int> = Set(board.enumerated().compactMap { idx, sq in
            markedIDs.contains(sq.id) ? idx : nil
        })
        let coins = tokenBalances[name]
        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(name)
                    .font(AmericanaTheme.barlowSemiBold(12))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.8))
                    .lineLimit(1)
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
            MiniGridView(markedPositions: markedPositions)
            Text("\(markedPositions.count) ✓")
                .font(AmericanaTheme.barlowSemiBold(10))
                .foregroundColor(AmericanaTheme.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
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
