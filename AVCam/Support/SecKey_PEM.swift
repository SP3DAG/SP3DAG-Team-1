import Foundation
import Security

extension SecKey {
    /// Converts the public key to PEM (Base64-encoded) format
    func toPEM() throws -> String {
        guard let publicKeyData = SecKeyCopyExternalRepresentation(self, nil) as Data? else {
            throw NSError(domain: "SecKey+PEM", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract public key data"])
        }

        // Add ASN.1 header for ECDSA public keys (for key type: ECSECPrimeRandom, 256-bit)
        let asn1Header: [UInt8] = [
            0x30, 0x59,
            0x30, 0x13,
            0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
            0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07,
            0x03, 0x42, 0x00
        ]
        let fullKey = Data(asn1Header) + publicKeyData

        let base64 = fullKey.base64EncodedString(options: [.lineLength64Characters])
        let pem = """
        -----BEGIN PUBLIC KEY-----
        \(base64)
        -----END PUBLIC KEY-----
        """
        return pem
    }
}
