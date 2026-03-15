import SwiftUI

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    // Sign out
    @State private var showSignOutConfirm = false

    // Kroger
    @State private var krogerEnabled: Bool = UserDefaults.standard.bool(forKey: "kroger_enabled")
    @State private var krogerClientId: String = KeychainHelper.shared.load(key: "kroger_client_id") ?? ""
    @State private var krogerClientSecret: String = KeychainHelper.shared.load(key: "kroger_client_secret") ?? ""
    @State private var krogerZip: String = UserDefaults.standard.string(forKey: "kroger_zip") ?? ""
    @State private var showKrogerSetup = false
    @State private var krogerTestState: TestState = .idle

    private enum TestState {
        case idle, loading, success(String), failure(String)
    }

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

                // MARK: - Price Lookup
                Section {
                    Toggle("Enable Kroger Price Lookup", isOn: $krogerEnabled)
                        .onChange(of: krogerEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "kroger_enabled")
                        }

                    if krogerEnabled {
                        HStack {
                            Image(systemName: "person.badge.key")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            SecureField("Client ID", text: $krogerClientId)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: krogerClientId) { _, v in
                                    KeychainHelper.shared.save(v.trimmingCharacters(in: .whitespacesAndNewlines), key: "kroger_client_id")
                                }
                        }

                        HStack {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            SecureField("Client Secret", text: $krogerClientSecret)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: krogerClientSecret) { _, v in
                                    KeychainHelper.shared.save(v.trimmingCharacters(in: .whitespacesAndNewlines), key: "kroger_client_secret")
                                }
                        }

                        HStack {
                            Image(systemName: "location")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            TextField("Zip Code (required for prices)", text: $krogerZip)
                                .keyboardType(.numberPad)
                                .onChange(of: krogerZip) { _, v in
                                    UserDefaults.standard.set(v, forKey: "kroger_zip")
                                }
                        }

                        // Test connection
                        Button {
                            testKrogerConnection()
                        } label: {
                            HStack {
                                switch krogerTestState {
                                case .idle:
                                    Label("Test Connection", systemImage: "wifi")
                                case .loading:
                                    ProgressView().controlSize(.small)
                                    Text("Testing…")
                                case .success(let msg):
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    Text(msg).foregroundStyle(.green)
                                case .failure(let msg):
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    Text(msg).foregroundStyle(.red)
                                }
                            }
                        }
                        .disabled(krogerClientId.isEmpty || krogerClientSecret.isEmpty)

                        Button {
                            showKrogerSetup = true
                        } label: {
                            Label("How to get credentials", systemImage: "questionmark.circle")
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                } header: {
                    Text("Price Lookup (Kroger)")
                } footer: {
                    if krogerEnabled {
                        Text("Prices are looked up from your nearest Kroger-family store (Kroger, Ralphs, Fred Meyer, King Soopers, etc.) when putting groceries away.")
                    } else {
                        Text("Optionally auto-fill prices during Put Away using the free Kroger developer API.")
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
            .sheet(isPresented: $showKrogerSetup) {
                KrogerSetupView()
            }
        }
    }

    private func testKrogerConnection() {
        guard !krogerClientId.isEmpty, !krogerClientSecret.isEmpty else { return }
        krogerTestState = .loading
        Task {
            do {
                try await KrogerService.shared.testConnection(clientId: krogerClientId, clientSecret: krogerClientSecret)
                await MainActor.run { krogerTestState = .success("Connected!") }
            } catch {
                await MainActor.run { krogerTestState = .failure(error.localizedDescription) }
            }
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run { krogerTestState = .idle }
        }
    }
}
