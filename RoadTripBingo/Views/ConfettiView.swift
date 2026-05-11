import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { _ in
            ForEach(particles) { p in
                Circle().fill(p.color).frame(width: p.size, height: p.size)
                    .position(p.position).opacity(p.opacity)
            }
        }
        .ignoresSafeArea().allowsHitTesting(false)
        .onAppear {
            particles = (0..<80).map { _ in ConfettiParticle() }
            withAnimation(.linear(duration: 2.5)) {
                for i in particles.indices {
                    particles[i].position.y += CGFloat.random(in: 600...900)
                    particles[i].position.x += CGFloat.random(in: -120...120)
                    particles[i].opacity = 0
                }
            }
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position = CGPoint(x: CGFloat.random(in: 0...1024), y: CGFloat.random(in: -200...0))
    let color = [Color.blue, .yellow, .red, .green, .orange, .purple].randomElement()!
    let size = CGFloat.random(in: 6...14)
    var opacity: Double = 1.0
}
