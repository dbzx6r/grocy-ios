import SwiftUI

struct ServerSetupView: View {
    @Environment(AppViewModel.self) private var appVM
    let onBack: () -> Void

    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var connectionSuccess = false
    @FocusState private var focusedField: Field?

    enum Field { case url, apiKey }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.green)
                    Text("Connect Your Server")
                        .font(.title.bold())
                    Text("Enter your Grocy server address and API key")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Form card
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Server URL", systemImage: "globe")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("http://192.168.1.100:9283", text: $serverURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .focused($focusedField, equals: .url)
                            .padding(12)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("API Key", systemImage: "key.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        SecureField("Your Grocy API key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .apiKey)
                            .padding(12)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }

                    Text("Get your API key from: Grocy → Settings → Manage API Keys")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)

                // Error
                if let err = appVM.connectionError {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                // Connect button
                Button {
                    focusedField = nil
                    Task {
                        let ok = await appVM.validateAndSave(url: serverURL, key: apiKey)
                        if ok {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                connectionSuccess = true
                            }
                        }
                    }
                } label: {
                    Group {
                        if appVM.isValidating {
                            ProgressView()
                                .tint(.white)
                        } else if connectionSuccess {
                            Label("Connected!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                        } else {
                            Label("Test Connection", systemImage: "arrow.right.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(connectionSuccess ? Color.green : Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: connectionSuccess)
                }
                .disabled(serverURL.isEmpty || apiKey.isEmpty || appVM.isValidating)
                .padding(.horizontal, 24)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                }
            }
        }
    }
}
