import SwiftUI

struct OpponentStripView: View {
    let opponentMarked: [String: Set<Int>]

    var body: some View {
        HStack(spacing: 24) {
            ForEach(opponentMarked.keys.sorted(), id: \.self) { name in
                let marked = opponentMarked[name] ?? []
                VStack(spacing: 6) {
                    Text(name).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.6))
                    MiniGridView(markedPositions: marked)
                    Text("\(marked.count) ✓").font(.system(size: 10)).foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color.white.opacity(0.05)).cornerRadius(12)
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
                            .fill(pos == 12 ? Color.yellow : markedPositions.contains(pos) ? Color.blue : Color.white.opacity(0.15))
                            .frame(width: size, height: size)
                    }
                }
            }
        }
    }
}
