import SwiftUI

struct TargetingOverlayView: View {
    let powerUp: PowerUpType
    let localBoard: BingoBoard?
    let opponentBoards: [String: [BingoSquare]]
    let opponentMarked: [String: Set<Int>]
    let onSelect: (_ targetPlayer: String?, _ targetIndex: Int) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 20) {
                HStack(spacing: 8) {
                    if let img = AmericanaTheme.icon(named: "powerup-\(powerUp.iconSlug)") {
                        img.resizable().scaledToFit().frame(width: 20, height: 20)
                    }
                    Text("Select target")
                        .font(AmericanaTheme.rye(17))
                        .foregroundColor(.white)
                    HStack(spacing: 3) {
                        Text("·")
                        if let img = AmericanaTheme.icon(named: "token") {
                            img.resizable().scaledToFit().frame(width: 16, height: 16)
                        }
                        Text("\(powerUp.cost)")
                            .font(AmericanaTheme.barlowBold(15))
                    }
                    .foregroundColor(AmericanaTheme.yellow)
                }

                if powerUp.affectsOpponent {
                    opponentGrid
                } else {
                    selfGrid
                }

                Button("Cancel") { onCancel() }
                    .font(AmericanaTheme.barlowSemiBold(15))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.8)
            .padding(24)
            .background(AmericanaTheme.ink)
            .cornerRadius(20)
            .padding(20)
        }
    }

    @ViewBuilder private var selfGrid: some View {
        if let board = localBoard {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                ForEach(0..<25, id: \.self) { idx in
                    let square = board.squares[idx]
                    let isFree = square.id == BingoSquare.freeSquareID
                    let isMarked = board.isMarked(at: idx)
                    let selectable: Bool = {
                        guard !isFree else { return false }
                        switch powerUp {
                        case .freeMark, .upgradeTileTargeted: return !isMarked
                        default: return true
                        }
                    }()
                    TargetTileView(square: square, isMarked: isMarked, isSelectable: selectable) {
                        if selectable { onSelect(nil, idx) }
                    }
                }
            }
        }
    }

    @ViewBuilder private var opponentGrid: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(opponentBoards.keys.sorted(), id: \.self) { oppName in
                    let oppBoard = opponentBoards[oppName] ?? []
                    let marked = opponentMarked[oppName] ?? []
                    VStack(spacing: 8) {
                        Text(oppName)
                            .font(AmericanaTheme.barlowSemiBold(14))
                            .foregroundColor(.white.opacity(0.65))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                            ForEach(0..<min(oppBoard.count, 25), id: \.self) { idx in
                                let square = oppBoard[idx]
                                let isFree = square.id == BingoSquare.freeSquareID
                                let isMarked = marked.contains(idx)
                                let selectable: Bool = {
                                    guard !isFree else { return false }
                                    if powerUp == .downgradeTileTargeted { return !isMarked }
                                    if powerUp == .unmarkOpponentTargeted { return isMarked }
                                    return false
                                }()
                                TargetTileView(square: square, isMarked: isMarked, isSelectable: selectable) {
                                    if selectable { onSelect(oppName, idx) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct TargetTileView: View {
    let square: BingoSquare
    let isMarked: Bool
    let isSelectable: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Group {
                if let img = AmericanaTheme.tileImage(for: square) {
                    img.resizable().scaledToFit()
                } else {
                    Text(square.emoji).font(.system(size: 14))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(square.text)
                .font(AmericanaTheme.barlowSemiBold(7))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(
            isMarked     ? AmericanaTheme.green.opacity(0.4) :
            isSelectable ? Color.white.opacity(0.12) :
                           Color.white.opacity(0.03)
        )
        .cornerRadius(6)
        .overlay(
            isSelectable
                ? RoundedRectangle(cornerRadius: 6)
                    .stroke(AmericanaTheme.yellow.opacity(0.8), lineWidth: 1.5)
                : nil
        )
        .opacity(isSelectable ? 1.0 : 0.35)
        .onTapGesture { onTap() }
    }
}

private extension PowerUpType {
    var iconSlug: String {
        switch self {
        case .upgradeTileRandom, .upgradeTileTargeted:        return "upgrade"
        case .downgradeTileRandom, .downgradeTileTargeted:   return "sabotage"
        case .freeMark:                                       return "freemark"
        case .unmarkOpponentRandom, .unmarkOpponentTargeted: return "erase"
        }
    }
}
