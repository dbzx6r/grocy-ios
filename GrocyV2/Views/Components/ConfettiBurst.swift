import SwiftUI

struct ConfettiBurst: View {
    @State private var particles: [ConfettiParticle] = []
    let colors: [Color] = [.green, .mint, .yellow, .orange, .pink, .blue, .purple]

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var color: Color
        var scale: CGFloat
        var opacity: Double
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: 8, height: 6)
                    .scaleEffect(p.scale)
                    .opacity(p.opacity)
                    .rotationEffect(.degrees(p.rotation))
                    .position(x: p.x, y: p.y)
            }
        }
        .allowsHitTesting(false)
        .onAppear { burst() }
    }

    private func burst() {
        let center = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY - 100)
        particles = (0..<30).map { _ in
            ConfettiParticle(
                x: center.x + CGFloat.random(in: -20...20),
                y: center.y,
                rotation: Double.random(in: 0...360),
                color: colors.randomElement() ?? .green,
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: 1.0
            )
        }

        for i in particles.indices {
            let dx = CGFloat.random(in: -150...150)
            let dy = CGFloat.random(in: -200 ... -50)
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(Double.random(in: 0...0.1))) {
                particles[i].x += dx
                particles[i].y += dy
                particles[i].rotation += Double.random(in: 180...720)
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.6)) {
                particles[i].opacity = 0
                particles[i].scale = 0.1
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            particles = []
        }
    }
}
