import UIKit
import CoreImage
import CoreGraphics

struct QRSteganography {
    
    let blockSize: Int
    
    /// Generates a QR code matrix (bit pattern) for a given string.
    func generateQRMatrix(from text: String) -> [[UInt8]] {
        let data = text.data(using: .isoLatin1)!
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else {
            print("Failed to generate QR CIImage")
            return [[]]
        }

        let scale = floor(47.0 / ciImage.extent.width)
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            print("Failed to create CGImage")
            return [[]]
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width == 47, height == 47 else {
            print("QR matrix is not 47x47, got \(width)x\(height)")
            return [[]]
        }

        var pixels = [UInt8](repeating: 0, count: width * height)
        var result = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)

        let grayContext = CGContext(data: &pixels, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width,
                                    space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: 0)!

        grayContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for y in 0..<height {
            for x in 0..<width {
                result[y][x] = pixels[y * width + x] < 128 ? 1 : 0
            }
        }

        return result
    }

    /// Flattens a 2D matrix to a 1D byte array.
    func flattenQRMatrix(_ matrix: [[UInt8]]) -> Data {
        return Data(matrix.flatMap { $0 })
    }

    /// Embeds multiple QR matrices along with their signature in the blue channel LSB of the image.
    func embedMultipleQRsInBlueChannel(image: UIImage, qrTexts: [String], spacing: Double = 20.0) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let context = CGContext(data: &pixelData,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let text = qrTexts.first else { return nil }

        let qrMatrix = generateQRMatrix(from: text)
        guard !qrMatrix.isEmpty else { return nil }

        let flattened = flattenQRMatrix(qrMatrix)
        guard let signature = try? KeyManager.sign(data: flattened) else {
            print("Failed to sign QR matrix")
            return nil
        }
        print(flattened.prefix(20).map { String(format: "%02x", $0) }.joined())
        print("Signature length: \(signature.count) bytes")
        
        let signatureLength = UInt8(signature.count)
        let lengthBits: [UInt8] = (0..<8).map { UInt8((signatureLength >> (7 - $0)) & 1) }
        
        let signatureBits: [UInt8] = signature.flatMap { byte in
            (0..<8).reversed().map { bit in UInt8((byte >> bit) & 1) }
        }
        
        let fullSignatureBits = lengthBits + signatureBits

        let qrH = qrMatrix.count
        let qrW = qrMatrix[0].count
        let block = blockSize
        let qrPixelH = qrH * block
        let qrPixelW = qrW * block

        let sigRows = Int(ceil(Double(fullSignatureBits.count) / Double(qrPixelW)))
        
        print("Embedding \(fullSignatureBits.count) bits over \(sigRows) rows and \(qrPixelW) columns")

        let totalHeightPerQR = qrPixelH + sigRows + 1

        let spacingPx = spacing // spacing in pixels (can be fractional)
        
        var row = 0
        while true {
            let offsetY = Int(round(Double(row) * (Double(totalHeightPerQR) + spacingPx)))
            if offsetY + totalHeightPerQR > height { break }

            var col = 0
            while true {
                let offsetX = Int(round(Double(col) * (Double(qrPixelW) + spacingPx)))
                if offsetX + qrPixelW > width { break }

                // Embed QR matrix
                for y in 0..<qrH {
                    for x in 0..<qrW {
                        let val = qrMatrix[y][x]
                        for dy in 0..<block {
                            for dx in 0..<block {
                                let px = offsetX + x * block + dx
                                let py = offsetY + y * block + dy
                                if px < width, py < height {
                                    let index = py * bytesPerRow + px * bytesPerPixel
                                    pixelData[index + 2] = (pixelData[index + 2] & 0xFE) | val
                                }
                            }
                        }
                    }
                }

                // Embed signature bits below the QR
                let sigStartY = offsetY + qrPixelH + 1
                var sigBitIndex = 0
                for py in sigStartY..<sigStartY + sigRows {
                    for px in 0..<qrPixelW {
                        if sigBitIndex >= fullSignatureBits.count { break }
                        let x = offsetX + px
                        let y = py
                        if x < width, y < height {
                            let index = y * bytesPerRow + x * bytesPerPixel
                            pixelData[index + 2] = (pixelData[index + 2] & 0xFE) | fullSignatureBits[sigBitIndex]
                            sigBitIndex += 1
                        }
                    }
                    if sigBitIndex >= fullSignatureBits.count { break }
                }

                col += 1
            }

            row += 1
        }

        let outputContext = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        guard let newCGImage = outputContext.makeImage() else { return nil }
        return UIImage(cgImage: newCGImage)
    }
}
