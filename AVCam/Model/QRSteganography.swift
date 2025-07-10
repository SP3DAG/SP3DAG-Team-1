import UIKit
import CoreImage
import CoreGraphics
import CryptoKit

struct QRSteganography {

    let blockSize = 8
    let modules = 125

    func embedTiledQR(in image: UIImage,
                      deviceID: String,
                      message: String) -> UIImage? {

        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width, height = cgImage.height
        let bytesPerPixel = 4, bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixelBuffer = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(data: &pixelBuffer,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let qrPixelSize = modules * blockSize
        let tilesX = width / qrPixelSize
        let tilesY = height / qrPixelSize

        print("Using QR with \(modules)x\(modules) modules (blockSize: \(blockSize)), grid \(tilesX)x\(tilesY)")

        let totalTiles = tilesX * tilesY

        let qrContext = CIContext()
        let qrFilter = CIFilter(name: "CIQRCodeGenerator")!

        // Lock for thread-safe pixel access
        let pixelLock = NSLock()

        DispatchQueue.concurrentPerform(iterations: totalTiles) { index in
            let tx = index % tilesX
            let ty = index / tilesX

            let x0 = tx * qrPixelSize
            let y0 = ty * qrPixelSize

            // 1. Batch hash upper 7 bits of RGB
            var hashInput = [UInt8]()
            for dy in 0..<qrPixelSize {
                let py = y0 + dy
                for dx in 0..<qrPixelSize {
                    let px = x0 + dx
                    let i = py * bytesPerRow + px * bytesPerPixel
                    hashInput.append(pixelBuffer[i]     & 0xFE)
                    hashInput.append(pixelBuffer[i + 1] & 0xFE)
                    hashInput.append(pixelBuffer[i + 2] & 0xFE)
                }
            }

            let hashHex = SHA256.hash(data: hashInput)
                                .map { String(format: "%02x", $0) }
                                .joined()

            // 2. Build and sign payload
            var payload: [String: Any] = [
                "device_id": deviceID,
                "tile_id": ty * tilesX + tx,
                "tile_count": tilesX * tilesY,
                "hash": hashHex,
                "message": message
            ]

            let jsonToSign = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            let signature = try! KeyManager.sign(data: jsonToSign)
            payload["sig"] = signature.map { String(format: "%02x", $0) }.joined()

            let fullJSON = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])

            // 3. Generate QR matrix once
            guard let qrMatrix = generateQRMatrix(from: fullJSON,
                                                  modules: modules,
                                                  qrFilter: qrFilter,
                                                  qrContext: qrContext)
            else {
                print("QR generation failed at tile (\(tx), \(ty))")
                return
            }

            // 4. Embed into blue-channel LSBs
            for my in 0..<modules {
                for mx in 0..<modules {
                    let bit = qrMatrix[my][mx]
                    for dy in 0..<blockSize {
                        for dx in 0..<blockSize {
                            let px = x0 + mx * blockSize + dx
                            let py = y0 + my * blockSize + dy
                            let i = py * bytesPerRow + px * bytesPerPixel
                            pixelLock.lock()
                            pixelBuffer[i + 2] = (pixelBuffer[i + 2] & 0xFE) | bit
                            pixelLock.unlock()
                        }
                    }
                }
            }
        }

        guard let outputCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: outputCGImage)
    }

    private func generateQRMatrix(from data: Data,
                                  modules: Int,
                                  qrFilter: CIFilter,
                                  qrContext: CIContext) -> [[UInt8]]? {

        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = qrFilter.outputImage else { return nil }

        let scale = CGFloat(modules) / ciImage.extent.width
        let transformed = ciImage.transformed(by: .init(scaleX: scale, y: scale))

        guard let cgImage = qrContext.createCGImage(transformed, from: transformed.extent) else { return nil }

        var grayBuffer = [UInt8](repeating: 0, count: modules * modules)
        let grayContext = CGContext(data: &grayBuffer,
                                    width: modules,
                                    height: modules,
                                    bitsPerComponent: 8,
                                    bytesPerRow: modules,
                                    space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: 0)!

        grayContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: modules, height: modules))

        return (0..<modules).map { y in
            (0..<modules).map { x in
                grayBuffer[y * modules + x] < 128 ? 1 : 0
            }
        }
    }
}
