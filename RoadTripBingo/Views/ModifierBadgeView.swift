import SwiftUI

private struct PopoverCompactAdaptationModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationCompactAdaptation(.popover)
        } else {
            content
        }
    }
}

struct ModifierBadgeView: View {
    let modifier: RoundModifier
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            HStack(spacing: 5) {
                Text(modifier.emoji)
                    .font(.system(size: 13))
                Text(modifier.shortName)
                    .font(AmericanaTheme.barlowBold(12))
                    .foregroundColor(AmericanaTheme.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(AmericanaTheme.parchment)
                    .overlay(Capsule().strokeBorder(AmericanaTheme.green, lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(modifier.emoji)
                        .font(.system(size: 22))
                    Text(modifier.shortName)
                        .font(AmericanaTheme.rye(15))
                        .foregroundColor(AmericanaTheme.ink)
                }
                Divider()
                Text(modifier.ruleDescription)
                    .font(AmericanaTheme.barlowSemiBold(13))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 240)
            .background(AmericanaTheme.parchment)
            .modifier(PopoverCompactAdaptationModifier())
        }
    }
}
