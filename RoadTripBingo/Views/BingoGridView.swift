import SwiftUI

struct BingoGridView: View {
    let board: BingoBoard
    let highlightedPositions: Set<Int>
    let onTap: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
    private let letters = ["B", "I", "N", "G", "O"]

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            gridArea
        }
        .shadow(color: AmericanaTheme.shadow, radius: 8, x: 0, y: 4)
        .task {
            let squares = board.squares
            Task.detached(priority: .userInitiated) {
                AmericanaTheme.prewarmTileImages(for: squares)
            }
        }
    }

    private var headerBar: some View {
        ZStack {
            AmericanaTheme.green

            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(AmericanaTheme.yellow)
                    .frame(width: 6)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 10)
                    .padding(.leading, 6)

                // B I N G O letters
                HStack(spacing: 0) {
                    ForEach(letters, id: \.self) { letter in
                        Text(letter)
                            .font(AmericanaTheme.rye(20))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Right accent bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(AmericanaTheme.yellow)
                    .frame(width: 6)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 10)
                    .padding(.trailing, 6)
            }
        }
        .frame(height: 44)
        .clipShape(
            RoundedCornerShape(radius: 12, corners: [.topLeft, .topRight])
        )
    }

    private var gridArea: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<25, id: \.self) { position in
                BingoSquareView(
                    square: board.squares[position],
                    isMarked: board.isMarked(at: position),
                    isHighlighted: highlightedPositions.contains(position),
                    onTap: { onTap(position) }
                ).aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(8)
        .background(
            AmericanaTheme.paper
                .clipShape(RoundedCornerShape(radius: 12, corners: [.bottomLeft, .bottomRight]))
        )
    }
}
