import SwiftUI

struct TokenToastView: View {
    let message: String
    let style: ToastStyle

    private var backgroundColor: Color {
        switch style {
        case .earn:   return AmericanaTheme.yellow
        case .threat: return AmericanaTheme.red
        }
    }

    private var textColor: Color {
        switch style {
        case .earn:   return AmericanaTheme.ink
        case .threat: return .white
        }
    }

    var body: some View {
        let parts = message.components(separatedBy: "🟡")
        HStack(spacing: 4) {
            if parts.count > 1 {
                Text(parts[0])
                if let img = AmericanaTheme.icon(named: "token") {
                    img.resizable().scaledToFit().frame(width: 18, height: 18)
                }
                if !parts[1].isEmpty {
                    Text(parts[1])
                }
            } else {
                Text(message)
            }
        }
        .font(AmericanaTheme.barlowBold(15))
        .foregroundColor(textColor)
        .padding(.horizontal, 18).padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(backgroundColor)
        )
        .shadow(color: AmericanaTheme.shadow, radius: 8, x: 0, y: 3)
    }
}
