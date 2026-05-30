import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            if let bg = AmericanaTheme.splashBackground() {
                bg.resizable().scaledToFill().ignoresSafeArea()
            } else {
                AmericanaTheme.gridBackground().ignoresSafeArea()
            }

            VStack(spacing: 6) {
                Text("ROAD TRIP")
                    .font(AmericanaTheme.rye(22))
                    .foregroundColor(.white.opacity(0.80))
                    .kerning(6)
                Text("BINGO")
                    .font(AmericanaTheme.rye(86))
                    .foregroundColor(AmericanaTheme.yellow)
                    .shadow(color: .black.opacity(0.25), radius: 0, x: 4, y: 4)
            }
            .padding(.horizontal, 52)
            .padding(.vertical, 22)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AmericanaTheme.green)
                        .shadow(color: Color(red: 0.059, green: 0.208, blue: 0.094), radius: 0, x: 0, y: 6)
                        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1.5)
                        .padding(7)
                    HStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AmericanaTheme.yellow)
                            .frame(width: 5)
                            .padding(.vertical, 14).padding(.leading, 14)
                        Spacer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AmericanaTheme.yellow)
                            .frame(width: 5)
                            .padding(.vertical, 14).padding(.trailing, 14)
                    }
                }
            )
        }
    }
}
