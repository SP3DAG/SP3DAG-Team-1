import Foundation

enum APIServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is invalid."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

struct VerificationResult: Decodable {
    let decoded_message: String
}

struct LinkTokenResponse: Decodable {
    let token: String
    let device_uuid: String
}

struct APIService {

    // Request a new link token and device UUID
    static func generateLinkToken() async throws -> LinkTokenResponse {
        guard let url = URL(string: "https://backend-dzm1.onrender.com/api/generate-link-token") else {
            throw APIServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIServiceError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(LinkTokenResponse.self, from: data)
        } catch {
            let msg = String(data: data, encoding: .utf8) ?? "Malformed response"
            throw APIServiceError.serverError(message: msg)
        }
    }

    // Updated to store device UUID after upload
    static func uploadLinkToken(token: String, publicKey: String) async throws -> Bool {
        guard let url = URL(string: "https://backend-dzm1.onrender.com/api/complete-link") else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"token\"\r\n\r\n")
        body.append("\(token)\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"public_key\"\r\n\r\n")
        body.append("\(publicKey)\r\n")

        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            let msg = String(data: data, encoding: .utf8) ?? "Invalid response"
            throw APIServiceError.serverError(message: msg)
        }

        if httpResponse.statusCode == 200 {
            struct LinkResponse: Decodable {
                let success: Bool
                let device_uuid: String
            }

            let decoded = try JSONDecoder().decode(LinkResponse.self, from: data)

            // Store in SessionManager
            SessionManager.shared.deviceID = decoded.device_uuid
            UserDefaults.standard.set(decoded.device_uuid, forKey: "deviceUUID")

            return decoded.success
        } else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIServiceError.serverError(message: msg)
        }
    }

    static func verifyImage(imageData: Data) async throws -> VerificationResult {
        guard let url = URL(string: "https://backend-dzm1.onrender.com/verify-image/") else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.png\"\r\n")
        body.append("Content-Type: image/png\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(VerificationResult.self, from: data)
        } else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIServiceError.serverError(message: msg)
        }
    }
}

// Utility for form-data
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
