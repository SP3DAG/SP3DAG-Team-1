import Foundation
import Security

struct KeyManager {
    static let tag = "com.denkmoritz.geocam.privatekey".data(using: .utf8)!

    // MARK: - Public API

    static func loadOrCreatePrivateKey() throws -> SecKey {
        if let key = loadPrivateKey() {
            return key
        } else {
            return try createPrivateKey()
        }
    }

    static func getPublicKey() throws -> SecKey {
        let privateKey = try loadOrCreatePrivateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NSError(domain: "KeyManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract public key"])
        }
        return publicKey
    }

    static func sign(data: Data) throws -> Data {
        let privateKey = try loadOrCreatePrivateKey()
        var error: Unmanaged<CFError>?

        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) else {
            throw error!.takeRetainedValue() as Error
        }

        return signature as Data
    }

    static func verify(data: Data, signature: Data, publicKey: SecKey) -> Bool {
        var error: Unmanaged<CFError>?

        let success = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            signature as CFData,
            &error
        )

        return success
    }

    static func getPublicKeyPEM() throws -> String {
        let publicKey = try getPublicKey()

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error!.takeRetainedValue()
        }

        let base64 = publicKeyData.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return """
        -----BEGIN PUBLIC KEY-----
        \(base64)
        -----END PUBLIC KEY-----
        """
    }

    // MARK: - Private Helpers

    private static func loadPrivateKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess {
            return item as! SecKey
        }
        return nil
    }

    private static func createPrivateKey() throws -> SecKey {
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            nil
        )!

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: access
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue()
        }

        return privateKey
    }
}
