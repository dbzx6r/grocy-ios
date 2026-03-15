import SwiftUI

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Server") {
                    LabeledContent("URL", value: appVM.serverURL)
                    LabeledContent("Mode", value: appVM.isDemoMode ? "Demo" : "Live")
                    if let info = appVM.systemInfo {
                        LabeledContent("Grocy Version", value: info.grocyVersion.version)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Label("Switch Server / Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    appVM.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will need to re-enter your server URL and API key.")
            }
        }
    }
}
