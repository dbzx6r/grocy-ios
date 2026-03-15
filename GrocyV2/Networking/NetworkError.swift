import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String?)
    case decodingError(Error)
    case notFound
    case unauthorized
    case timeout
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL. Please check your server address."
        case .invalidResponse: return "Unexpected response from server."
        case .httpError(let code, let msg): return "Server error \(code): \(msg ?? "Unknown error")"
        case .decodingError: return "Could not parse server response."
        case .notFound: return "Product not found."
        case .unauthorized: return "Invalid API key. Please check your credentials."
        case .timeout: return "Request timed out. Check your network connection."
        case .unknown(let e): return e.localizedDescription
        }
    }
}
