import SwiftUI

struct BingoGridView: View {
    let board: BingoBoard
    let highlightedPositions: Set<Int>
    let onTap: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<25, id: \.self) { position in
                BingoSquareView(
                    square: board.squares[position],
                    isMarked: board.isMarked(at: position),
                    isHighlighted: highlightedPositions.contains(position),
                    onTap: { onTap(position) }
                ).aspectRatio(1, contentMode: .fit)
            }
        }
    }
}
