import SwiftUI

struct TokenToastView: View {
    let message: String
    let style: ToastStyle

    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(style == .earn
                ? Color.yellow.opacity(0.95)
                : Color.orange.opacity(0.95))
            .foregroundColor(.black)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.25), radius: 8)
    }
}
