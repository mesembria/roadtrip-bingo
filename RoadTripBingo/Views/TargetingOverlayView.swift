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
                Text("\(powerUp.emoji)  Select target  ·  \(powerUp.cost)🪙")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if powerUp.affectsOpponent {
                    opponentGrid
                } else {
                    selfGrid
                }

                Button("Cancel") { onCancel() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(24)
            .background(Color(red: 0.10, green: 0.14, blue: 0.22))
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
                        return powerUp == .freeMark ? !isMarked : true
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
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
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
            Text(square.emoji).font(.system(size: 14))
            Text(square.text)
                .font(.system(size: 7, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(
            isMarked     ? Color.blue.opacity(0.35) :
            isSelectable ? Color.white.opacity(0.12) :
                           Color.white.opacity(0.03)
        )
        .cornerRadius(6)
        .overlay(
            isSelectable
                ? RoundedRectangle(cornerRadius: 6).stroke(Color.yellow.opacity(0.6), lineWidth: 1)
                : nil
        )
        .opacity(isSelectable ? 1.0 : 0.35)
        .onTapGesture { onTap() }
    }
}
