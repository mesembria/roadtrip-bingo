import SwiftUI

struct PowerUpHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private struct HelpItem: Identifiable {
        let id = UUID()
        let emoji: String
        let name: String
        let description: String
        let tapDetail: String?
        let holdDetail: String
    }

    private let items: [HelpItem] = [
        HelpItem(
            emoji: "🔀", name: "Upgrade",
            description: "Swap one of your tiles for an easier one.",
            tapDetail: "replaces your hardest tile (3🪙)",
            holdDetail: "you pick the tile (7🪙)"
        ),
        HelpItem(
            emoji: "💣", name: "Sabotage",
            description: "Make an opponent's unmarked tile harder.",
            tapDetail: "random tile (3🪙)",
            holdDetail: "you pick the tile (7🪙)"
        ),
        HelpItem(
            emoji: "✅", name: "Free Mark",
            description: "Mark any of your tiles without spotting it.",
            tapDetail: nil,
            holdDetail: "you pick the tile (5🪙)"
        ),
        HelpItem(
            emoji: "💥", name: "Erase",
            description: "Remove a mark from an opponent's board.",
            tapDetail: "their most recent mark (4🪙)",
            holdDetail: "you pick the tile (7🪙)"
        ),
    ]

    var body: some View {
        NavigationStack {
            List(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.emoji).font(.title2)
                        Text(item.name).font(.headline)
                    }
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let tap = item.tapDetail {
                        Text("Tap: \(tap) · Hold: \(item.holdDetail)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Hold: \(item.holdDetail)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Power-Ups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                }
            }
        }
    }
}
