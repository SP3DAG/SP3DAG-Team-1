import UIKit
import CoreImage
import CryptoKit

class VerificationViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    private let statusLabel = UILabel()
    
    private let uploadButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Upload Image", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Verify QR Signature"
        
        setupUI()
    }
    
    private func setupUI() {
        title = "Verify QR Signature"
        view.backgroundColor = .systemBackground
        
        statusLabel.text = "No image selected, please upload an image"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        
        uploadButton.addTarget(self, action: #selector(selectImage), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [statusLabel, uploadButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    @objc private func selectImage() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let image = info[.originalImage] as? UIImage else {
            statusLabel.text = "Failed to load image"
            return
        }
        
        verifyImage(image)
    }
    
    private func verifyImage(_ image: UIImage) {
        statusLabel.text = "Verifying..."
        
        let qrBlockSize = 8
        let qrSize = 47
        
        guard let cgImage = image.cgImage else {
            statusLabel.text = "Invalid image format"
            return
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            statusLabel.text = "Failed to create image context"
            return
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Extract QR matrix
        let qrMatrix = (0..<qrSize).map { y in
            (0..<qrSize).map { x in
                let px = x * qrBlockSize
                let py = y * qrBlockSize
                let index = py * bytesPerRow + px * bytesPerPixel
                return pixelData[index + 2] & 1
            }
        }
        print("Extracted QR Matrix Preview (first 5 rows):")
        for row in qrMatrix.prefix(5) {
            print(row.map { String($0) }.joined())
        }
        for y in 0..<2 {
            for x in 0..<5 {
                let px = x * qrBlockSize
                let py = y * qrBlockSize
                let index = py * bytesPerRow + px * bytesPerPixel
                let blue = pixelData[index + 2]
                let bit = blue & 1
                print("Swift Pixel (\(px), \(py)) blue: \(blue), bit: \(bit)")
            }
        }
        
        let steg = QRSteganography(blockSize: qrBlockSize)
        let flattened = steg.flattenQRMatrix(qrMatrix)
        print("Flattened QR bytes (first 20): \(flattened.prefix(20).map { String(format: "%02x", $0) }.joined())")
        
        // Extract signature bits below QR
        var extractedBits: [UInt8] = []
        
        let qrPixelH = qrSize * qrBlockSize
        let qrPixelW = qrSize * qrBlockSize
        let sigStartY = qrPixelH + 1
        let maxBitsToExtract = 8 + 72 * 8 // 1 byte for length + up to 72-byte signature
        
        for row in 0..<3 {
            for col in 0..<qrPixelW {
                if extractedBits.count >= maxBitsToExtract { break }
                let x = col
                let y = sigStartY + row
                if x >= width || y >= height { continue }
                let index = y * bytesPerRow + x * bytesPerPixel
                extractedBits.append(pixelData[index + 2] & 1)
            }
        }
        
        // Parse signature length (first 8 bits)
        let lengthByteBits = extractedBits.prefix(8)
        let signatureLength = lengthByteBits.reduce(0) { ($0 << 1) | $1 }
        
        // Validate signature length
        guard signatureLength > 0 && signatureLength <= 72 else {
            statusLabel.text = "Invalid signature length: \(signatureLength)"
            return
        }
        
        let signatureBitCount = Int(signatureLength) * 8
        
        // Extract only the signature bits
        let signatureBits = extractedBits.dropFirst(8).prefix(signatureBitCount)
        
        // Convert bits to bytes safely
        let sigBytes = stride(from: 0, to: signatureBits.count, by: 8).compactMap { i -> UInt8? in
            let byteBits = signatureBits.dropFirst(i).prefix(8)
            guard byteBits.count == 8 else { return nil }
            return byteBits.reduce(0) { ($0 << 1) | $1 }
        }
        
        // Debug info
        let hash = SHA256.hash(data: flattened)
        print("Flattened QR matrix SHA256: \(hash.compactMap { String(format: "%02x", $0) }.joined())")
        
        let sigPreview = sigBytes.prefix(10).map { String(format: "%02x", $0) }.joined()
        print("Extracted signature (first 10 bytes): \(sigPreview)")
        print("Signature byte count: \(sigBytes.count)")
        
        do {
            let publicKey = try KeyManager.getPublicKey()
            let isValid = KeyManager.verify(data: flattened, signature: Data(sigBytes), publicKey: publicKey)
            statusLabel.text = isValid ? "Signature is VALID" : "Signature is INVALID"
            uploadButton.setTitle("Validate Another Image", for: .normal)
        } catch {
            statusLabel.text = "Error verifying signature: \(error.localizedDescription)"
            uploadButton.setTitle("Validate Another Image", for: .normal)
        }
    }
}
