import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var step: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome, serverSetup, demoIntro
    }

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [Color.green.opacity(0.15), Color.mint.opacity(0.08), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch step {
            case .welcome:
                WelcomeView(
                    onConnect: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            step = .serverSetup
                        }
                    },
                    onDemo: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            step = .demoIntro
                        }
                    }
                )
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))

            case .serverSetup:
                ServerSetupView(
                    onBack: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            step = .welcome
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))

            case .demoIntro:
                DemoIntroView(
                    onBack: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            step = .welcome
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)
    }
}
