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

struct APIService {
    
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
            return true
        } else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIServiceError.serverError(message: msg)
        }
    }
    
    static func verifyImage(deviceUUID: String, imageData: Data) async throws -> VerificationResult {
        guard let url = URL(string: "https://backend-dzm1.onrender.com/verify-image/") else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Device UUID field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"device_uuid\"\r\n\r\n")
        body.append("\(deviceUUID)\r\n")

        // Image file field
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

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
