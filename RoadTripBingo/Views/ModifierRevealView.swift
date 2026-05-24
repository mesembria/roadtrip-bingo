import SwiftUI

struct ModifierRevealView: View {
    let modifier: RoundModifier
    let onDismiss: () -> Void

    @State private var countdown = 3
    @State private var cardOffset: CGFloat = 800
    @State private var backgroundOpacity: Double = 0
    @State private var emojiScale: CGFloat = 0.3
    @State private var emojiOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .opacity(backgroundOpacity)

            VStack {
                Spacer()
                signCard
                    .offset(y: cardOffset)
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                backgroundOpacity = 1
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.1)) {
                cardOffset = 0
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.45)) {
                emojiScale = 1.0
                emojiOpacity = 1.0
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                withAnimation(.easeIn(duration: 0.25)) {
                    backgroundOpacity = 0
                    cardOffset = 800
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }

    private var signCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(AmericanaTheme.ink)
                .padding(-5)

            RoundedRectangle(cornerRadius: 16)
                .fill(AmericanaTheme.paper)

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(AmericanaTheme.brown.opacity(0.45), lineWidth: 2)
                .padding(14)

            VStack(spacing: 14) {
                Text(modifier.emoji)
                    .font(.system(size: 84))
                    .scaleEffect(emojiScale)
                    .opacity(emojiOpacity)
                    .shadow(color: AmericanaTheme.ink.opacity(0.15), radius: 4, x: 0, y: 3)

                Text(modifier.shortName.uppercased())
                    .font(AmericanaTheme.rye(28))
                    .foregroundColor(AmericanaTheme.ink)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Rectangle()
                        .fill(AmericanaTheme.brown.opacity(0.35))
                        .frame(height: 1)
                    Image(systemName: "star.fill")
                        .font(.system(size: 7))
                        .foregroundColor(AmericanaTheme.brown.opacity(0.4))
                    Rectangle()
                        .fill(AmericanaTheme.brown.opacity(0.35))
                        .frame(height: 1)
                }
                .padding(.horizontal, 32)

                Text(modifier.ruleDescription)
                    .font(AmericanaTheme.barlowSemiBold(15))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 4)

                ZStack {
                    Capsule().fill(AmericanaTheme.yellow)
                    Capsule().strokeBorder(AmericanaTheme.ink.opacity(0.18), lineWidth: 1)
                    Text(countdown > 0 ? "Starting in \(countdown)…" : "Go!")
                        .font(AmericanaTheme.barlowBold(15))
                        .foregroundColor(AmericanaTheme.ink)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                }
                .fixedSize()
            }
            .padding(.vertical, 34)
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: 500)
        .padding(.horizontal, 60)
    }
}
