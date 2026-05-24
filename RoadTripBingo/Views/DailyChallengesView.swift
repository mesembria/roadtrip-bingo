import SwiftUI

struct DailyChallengesView: View {
    let challenges: [DailyChallenge]
    let completedIDs: Set<String>

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                challengesSection
            }
        }
        .background(AmericanaTheme.parchment)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            roadDivider
            VStack(spacing: 6) {
                Text("🗺️")
                    .font(.system(size: 32))
                Text("Today's Challenges")
                    .font(AmericanaTheme.rye(26))
                    .foregroundColor(AmericanaTheme.ink)
                Text("Complete these to earn bonus tokens")
                    .font(AmericanaTheme.barlowSemiBold(14))
                    .foregroundColor(AmericanaTheme.ink.opacity(0.6))
            }
            .padding(.vertical, 20)
            roadDivider
        }
        .padding(.horizontal, 24)
    }

    private var roadDivider: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(AmericanaTheme.brown.opacity(0.3))
                .frame(height: 1)
            Image(systemName: "car.fill")
                .font(.system(size: 10))
                .foregroundColor(AmericanaTheme.brown.opacity(0.4))
            Rectangle()
                .fill(AmericanaTheme.brown.opacity(0.3))
                .frame(height: 1)
        }
    }

    private var challengesSection: some View {
        VStack(spacing: 14) {
            ForEach(challenges) { challenge in
                challengeCard(challenge)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private func challengeCard(_ challenge: DailyChallenge) -> some View {
        challengeCardContent(challenge, isCompleted: completedIDs.contains(challenge.id))
    }

    private func challengeCardContent(_ challenge: DailyChallenge, isCompleted: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isCompleted ? AmericanaTheme.paper.opacity(0.5) : AmericanaTheme.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AmericanaTheme.ink.opacity(isCompleted ? 0.08 : 0.18), lineWidth: 1)
                )

            // Left accent stripe
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCompleted ? AmericanaTheme.green.opacity(0.5) : AmericanaTheme.green)
                    .frame(width: 6)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AmericanaTheme.parchment.opacity(isCompleted ? 0.5 : 1.0))
                        .frame(width: 48, height: 48)
                    Text(challenge.emoji)
                        .font(.system(size: 24))
                        .opacity(isCompleted ? 0.45 : 1.0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(challenge.title)
                        .font(AmericanaTheme.barlowBold(15))
                        .foregroundColor(AmericanaTheme.ink.opacity(isCompleted ? 0.35 : 1.0))
                    Text(challenge.description)
                        .font(AmericanaTheme.barlowSemiBold(12))
                        .foregroundColor(AmericanaTheme.ink.opacity(isCompleted ? 0.25 : 0.6))
                }

                Spacer()

                if isCompleted {
                    ZStack {
                        Circle()
                            .fill(AmericanaTheme.green)
                            .frame(width: 36, height: 36)
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    ZStack {
                        Capsule().fill(AmericanaTheme.yellow)
                        Capsule().strokeBorder(AmericanaTheme.ink.opacity(0.15), lineWidth: 1)
                        Text("+\(challenge.tokenReward) 🟡")
                            .font(AmericanaTheme.barlowBold(13))
                            .foregroundColor(AmericanaTheme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .fixedSize()
                }
            }
            .padding(.horizontal, 16)
            .padding(.leading, 6)
            .padding(.vertical, 14)
        }
        .frame(minHeight: 76)
    }
}
