import Foundation

struct KrogerPrice: Sendable {
    let regular: Double
    let promo: Double?
    let storeName: String?
}

private struct KrogerTokenResponse: Decodable {
    let accessToken: String
}

private struct KrogerLocationsResponse: Decodable {
    let data: [KrogerLocation]
}

private struct KrogerLocation: Decodable {
    let locationId: String
    let name: String?
}

private struct KrogerProductsResponse: Decodable {
    let data: [KrogerProductItem]
}

private struct KrogerProductItem: Decodable {
    let items: [KrogerItemEntry]?
}

private struct KrogerItemEntry: Decodable {
    let price: KrogerItemPrice?
}

private struct KrogerItemPrice: Decodable {
    let regular: Double
    let promo: Double?
}

enum KrogerServiceError: LocalizedError {
    case missingCredentials
    case authFailed(String)
    case notFound
    case noLocation
    case locationNotFound

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Kroger credentials not configured."
        case .authFailed(let detail): return detail
        case .notFound: return "Price not found for this product."
        case .noLocation: return "Set your zip code in Settings → Price Lookup to enable store pricing."
        case .locationNotFound: return "No Kroger store found near your zip code. Try a nearby zip."
        }
    }
}

actor KrogerService {
    static let shared = KrogerService()
    private init() {}

    private let baseURL = "https://api.kroger.com/v1"
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Public

    func lookupPrice(searchTerm: String) async throws -> KrogerPrice {
        guard let clientId = KeychainHelper.shared.load(key: "kroger_client_id"),
              let clientSecret = KeychainHelper.shared.load(key: "kroger_client_secret"),
              !clientId.isEmpty, !clientSecret.isEmpty
        else { throw KrogerServiceError.missingCredentials }

        let zipCode = UserDefaults.standard.string(forKey: "kroger_zip") ?? ""
        guard !zipCode.isEmpty else { throw KrogerServiceError.noLocation }

        let token = try await getToken(clientId: clientId, clientSecret: clientSecret)
        guard let location = try await lookupLocation(zip: zipCode, token: token) else {
            throw KrogerServiceError.locationNotFound
        }
        return try await fetchPrice(searchTerm: searchTerm, locationId: location.id, token: token, storeName: location.name)
    }

    func testConnection(clientId: String, clientSecret: String) async throws {
        _ = try await getToken(clientId: clientId, clientSecret: clientSecret)
    }

    // MARK: - Internal

    private func getToken(clientId: String, clientSecret: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/connect/oauth2/token") else {
            throw KrogerServiceError.authFailed("Invalid token URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let cleanId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let credentials = "\(cleanId):\(cleanSecret)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        // scope=product.compact is required for the Products API to return price data
        request.httpBody = "grant_type=client_credentials&scope=product.compact".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            // Extract a readable message from Kroger's error JSON if possible
            let detail: String
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error_description"] as? String ?? obj["message"] as? String {
                detail = "\(status): \(msg)"
            } else if !body.isEmpty {
                detail = "HTTP \(status): \(body.prefix(120))"
            } else {
                detail = "HTTP \(status) — check your Client ID and Secret"
            }
            throw KrogerServiceError.authFailed(detail)
        }
        let tokenResponse = try decoder.decode(KrogerTokenResponse.self, from: data)
        return tokenResponse.accessToken
    }

    private func lookupLocation(zip: String, token: String) async throws -> (id: String, name: String?)? {
        guard var comps = URLComponents(string: "\(baseURL)/locations") else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "filter.zipCode.near", value: zip),
            URLQueryItem(name: "filter.limit", value: "1")
        ]
        guard let url = comps.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let locs = try decoder.decode(KrogerLocationsResponse.self, from: data)
        guard let first = locs.data.first else { return nil }
        return (id: first.locationId, name: first.name)
    }

    private func fetchPrice(searchTerm: String, locationId: String?, token: String, storeName: String?) async throws -> KrogerPrice {
        guard var comps = URLComponents(string: "\(baseURL)/products") else { throw KrogerServiceError.notFound }
        var queryItems = [URLQueryItem(name: "filter.term", value: searchTerm)]
        if let locationId {
            queryItems.append(URLQueryItem(name: "filter.locationId", value: locationId))
        }
        comps.queryItems = queryItems
        guard let url = comps.url else { throw KrogerServiceError.notFound }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw KrogerServiceError.notFound
        }
        let productsResponse = try decoder.decode(KrogerProductsResponse.self, from: data)
        // Products may be returned but without price if locationId is missing or item isn't sold at that store
        guard let price = productsResponse.data.first?.items?.first?.price else {
            throw KrogerServiceError.notFound
        }
        return KrogerPrice(regular: price.regular, promo: price.promo, storeName: storeName)
    }
}
