import SwiftUI
import Observation

@Observable
@MainActor
final class AppViewModel {
    var isOnboarded: Bool = false
    var isDemoMode: Bool = false
    var serverURL: String = ""
    var apiKey: String = ""
    var client: GrocyAPIClient?
    var systemInfo: SystemInfo?
    var connectionError: String?
    var isValidating: Bool = false
    
    static let demoURL = "https://demo.grocy.info"
    static let demoKey = "demo_mode"
    
    init() {
        loadCredentials()
    }
    
    func loadCredentials() {
        let url = KeychainHelper.shared.load(key: KeychainKeys.serverURL) ?? ""
        let key = KeychainHelper.shared.load(key: KeychainKeys.apiKey) ?? ""
        isDemoMode = UserDefaults.standard.bool(forKey: "isDemoMode")
        if !url.isEmpty && !key.isEmpty {
            serverURL = url
            apiKey = key
            client = GrocyAPIClient(baseURL: url, apiKey: key)
            isOnboarded = true
        }
    }
    
    func validateAndSave(url: String, key: String) async -> Bool {
        isValidating = true
        connectionError = nil
        let testClient = GrocyAPIClient(baseURL: url, apiKey: key)
        do {
            systemInfo = try await testClient.getSystemInfo()
            serverURL = url
            apiKey = key
            client = testClient
            KeychainHelper.shared.save(url, key: KeychainKeys.serverURL)
            KeychainHelper.shared.save(key, key: KeychainKeys.apiKey)
            UserDefaults.standard.set(false, forKey: "isDemoMode")
            isDemoMode = false
            isOnboarded = true
            isValidating = false
            return true
        } catch {
            connectionError = error.localizedDescription
            isValidating = false
            return false
        }
    }
    
    func connectDemo() async -> Bool {
        isValidating = true
        connectionError = nil
        let demoClient = GrocyAPIClient(baseURL: Self.demoURL, apiKey: Self.demoKey)
        do {
            systemInfo = try await demoClient.getSystemInfo()
            serverURL = Self.demoURL
            apiKey = Self.demoKey
            client = demoClient
            KeychainHelper.shared.save(Self.demoURL, key: KeychainKeys.serverURL)
            KeychainHelper.shared.save(Self.demoKey, key: KeychainKeys.apiKey)
            UserDefaults.standard.set(true, forKey: "isDemoMode")
            isDemoMode = true
            isOnboarded = true
            isValidating = false
            return true
        } catch {
            connectionError = "Could not connect to demo server: \(error.localizedDescription)"
            isValidating = false
            return false
        }
    }
    
    func signOut() {
        KeychainHelper.shared.clearAll()
        UserDefaults.standard.removeObject(forKey: "isDemoMode")
        client = nil
        serverURL = ""
        apiKey = ""
        isDemoMode = false
        isOnboarded = false
        systemInfo = nil
    }
}
