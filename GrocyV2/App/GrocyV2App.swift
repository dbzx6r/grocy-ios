import SwiftUI

@main
struct GrocyV2App: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            if appViewModel.isOnboarded {
                ContentView()
                    .environment(appViewModel)
            } else {
                OnboardingFlow()
                    .environment(appViewModel)
            }
        }
    }
}
