import SwiftUI

struct KrogerSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    private let steps: [SetupStep] = [
        SetupStep(
            icon: "cart.badge.plus",
            iconColor: .blue,
            title: "Kroger Price Lookup",
            subtitle: "Free · Takes about 2 minutes",
            body: "This feature looks up current prices at your nearest Kroger-family store (Kroger, Ralphs, Fred Meyer, King Soopers, and more) when you put groceries away.\n\nYou'll need a free Kroger Developer account. We'll walk you through it.",
            action: nil
        ),
        SetupStep(
            icon: "person.badge.plus",
            iconColor: .green,
            title: "Create a Free Account",
            subtitle: "Step 1 of 3",
            body: "Visit the Kroger Developer Portal and sign up for a free account. No credit card required.",
            action: SetupAction(label: "Open developer.kroger.com", url: "https://developer.kroger.com")
        ),
        SetupStep(
            icon: "doc.badge.plus",
            iconColor: .orange,
            title: "Create an Application",
            subtitle: "Step 2 of 3",
            body: "Once logged in:\n\n1. Tap **Create App** or **New Application**\n2. Give it a unique name (e.g. \"GrocyHome\" + your last name — names must be globally unique)\n3. When asked for environment, select **Production** (not Certification)\n4. Under **Scopes**, check **Product** (covers both product search and store locations)\n5. Save the application",
            action: nil
        ),
        SetupStep(
            icon: "key.fill",
            iconColor: .purple,
            title: "Copy Your Credentials",
            subtitle: "Step 3 of 3",
            body: "After creating the app you'll see two values:\n\n• **Client ID** — a long alphanumeric string\n• **Client Secret** — keep this private, like a password\n\nCopy both — you'll paste them in the next step.",
            action: nil
        ),
        SetupStep(
            icon: "checkmark.seal.fill",
            iconColor: .mint,
            title: "You're Ready!",
            subtitle: "Paste your credentials in Settings",
            body: "Head back to Settings → Price Lookup (Kroger) and paste your Client ID and Client Secret into the fields there.\n\n**Important:** Also enter your zip code — this is required for Kroger to return store-specific prices. Without it, price lookups will not work.",
            action: nil
        )
    ]

    var body: some View {
        NavigationStack {
            TabView(selection: $currentStep) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    StepPage(step: step)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationTitle("Kroger Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        if currentStep > 0 {
                            Button("Back") {
                                withAnimation { currentStep -= 1 }
                            }
                        }
                        Spacer()
                        if currentStep < steps.count - 1 {
                            Button("Next") {
                                withAnimation { currentStep += 1 }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Done") { dismiss() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Models

private struct SetupStep {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let body: String
    let action: SetupAction?
}

private struct SetupAction {
    let label: String
    let url: String
}

// MARK: - Step Page

private struct StepPage: View {
    let step: SetupStep

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 20)

                // Icon
                ZStack {
                    Circle()
                        .fill(step.iconColor.opacity(0.15))
                        .frame(width: 96, height: 96)
                    Image(systemName: step.icon)
                        .font(.system(size: 42))
                        .foregroundStyle(step.iconColor)
                }
                .padding(.top, 12)

                // Title
                VStack(spacing: 6) {
                    Text(step.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(step.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Body
                Text(try! AttributedString(markdown: step.body, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Action button
                if let action = step.action, let url = URL(string: action.url) {
                    Link(destination: url) {
                        Label(action.label, systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 32)
                }

                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    KrogerSetupView()
}
