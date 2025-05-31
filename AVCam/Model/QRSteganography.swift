//
//  QRSteganography.swift
//  AVCam
//
//  Created by Moritz Denk on 31.05.25.
//  Copyright © 2025 Apple. All rights reserved.
//

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

    /// Embeds multiple QR matrices tiled in the blue channel LSB of the image.
    func embedMultipleQRsInBlueChannel(image: UIImage, qrMatrix: [[UInt8]], spacingMultiplier: Int = 1) -> UIImage? {
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

        let qrH = qrMatrix.count
        let qrW = qrMatrix[0].count
        let block = blockSize
        let qrPixelH = qrH * block
        let qrPixelW = qrW * block

        let maxRows = height / (qrPixelH * spacingMultiplier)
        let maxCols = width / (qrPixelW * spacingMultiplier)

        for row in 0..<maxRows {
                for col in 0..<maxCols {
                    let offsetY = row * qrPixelH * spacingMultiplier
                    let offsetX = col * qrPixelW * spacingMultiplier
                for y in 0..<qrH {
                    for x in 0..<qrW {
                        let val = qrMatrix[y][x]
                        for dy in 0..<block {
                            for dx in 0..<block {
                                let px = offsetX + x * block + dx
                                let py = offsetY + y * block + dy
                                if px < width, py < height {
                                    let index = py * bytesPerRow + px * bytesPerPixel
                                    pixelData[index + 2] = (pixelData[index + 2] & 0xFE) | val // Blue LSB
                                }
                            }
                        }
                    }
                }
            }
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
