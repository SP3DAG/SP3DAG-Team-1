import Foundation

enum APIServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case network(String)

    // Semantic server feedback
    case noQrFound
    case inconsistentQr
    case badSignature
    case unsupportedFile
    case serverError(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is invalid."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .network(let msg):
            return msg

        // user-facing messages
        case .noQrFound:
            return "We couldn’t find a signed QR code in that image."
        case .inconsistentQr:
            return "Different QR copies in the image disagree. Please retake the photo."
        case .badSignature:
            return "The image’s QR signature is invalid — it may have been tampered with."
        case .unsupportedFile:
            return "That file isn’t a PNG or JPEG I can read."
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

struct VerificationResult: Decodable {
    let decoded_message: String
    let status: String
}

struct LinkTokenResponse: Decodable {
    let token: String
    let device_uuid: String
}

// For decoding error envelopes: { "detail": "..." }
private struct APIErrorEnvelope: Decodable {
    let detail: String
}

struct APIService {

    // Generate link token
    static func generateLinkToken() async throws -> LinkTokenResponse {
        guard let url = URL(string: "https://backend-dzm1.onrender.com/api/generate-link-token") else {
            throw APIServiceError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw APIServiceError.invalidResponse
            }

            guard http.statusCode == 200 else {
                let detail = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIServiceError.serverError(message: detail)
            }

            return try JSONDecoder().decode(LinkTokenResponse.self, from: data)

        } catch let urlErr as URLError {
            throw APIServiceError.network(urlErr.localizedDescription)
        }
    }

    // Upload public key & complete link
    static func uploadLinkToken(token: String, publicKey: String) async throws -> Bool {
        guard let url = URL(string: "https://backend-dzm1.onrender.com/api/complete-link") else {
            throw APIServiceError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendFormField(named: "token", value: token, using: boundary)
        body.appendFormField(named: "public_key", value: publicKey, using: boundary)
        body.append("--\(boundary)--\r\n")
        req.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw APIServiceError.invalidResponse
            }

            guard http.statusCode == 200 else {
                let detail = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIServiceError.serverError(message: detail)
            }

            // success payload
            struct LinkResponse: Decodable { let success: Bool; let device_uuid: String }
            let decoded = try JSONDecoder().decode(LinkResponse.self, from: data)

            SessionManager.shared.deviceID = decoded.device_uuid
            UserDefaults.standard.set(decoded.device_uuid, forKey: "deviceUUID")
            return decoded.success

        } catch let urlErr as URLError {
            throw APIServiceError.network(urlErr.localizedDescription)
        }
    }

    // Verify image (multi-QR aware)
    static func verifyImage(imageData: Data) async throws -> VerificationResult {
        guard let url = URL(string: "https://backend-dzm1.onrender.com/verify-image/") else {
            throw APIServiceError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.png\"\r\n")
        body.append("Content-Type: image/png\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        req.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw APIServiceError.invalidResponse
            }

            // - Success -
            if (200..<300).contains(http.statusCode) {
                return try JSONDecoder().decode(VerificationResult.self, from: data)
            }

            // - Error path -
            let detail = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.detail
                         ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)

            switch detail {
            case _ where detail.contains("No valid"):
                throw APIServiceError.noQrFound
            case _ where detail.contains("Inconsistent"):
                throw APIServiceError.inconsistentQr
            case _ where detail.contains("Signature"):
                throw APIServiceError.badSignature
            case _ where detail.contains("convert image"):
                throw APIServiceError.unsupportedFile
            default:
                throw APIServiceError.serverError(message: detail)
            }

        } catch let urlErr as URLError {
            throw APIServiceError.network(urlErr.localizedDescription)
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }

    mutating func appendFormField(named name: String, value: String, using boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }
}
