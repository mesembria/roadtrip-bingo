import SwiftUI

struct TokenToastView: View {
    let message: String
    let style: ToastStyle

    private var backgroundColor: Color {
        switch style {
        case .earn:   return Color.yellow.opacity(0.95)
        case .threat: return Color.orange.opacity(0.95)
        }
    }

    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(backgroundColor)
            .foregroundColor(.black)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.25), radius: 8)
    }
}
