import UIKit
import CoreImage
import CoreGraphics
import CryptoKit

struct QRSteganography {

    /// Fixed-size modules (each module is an 8×8 px square).
    let blockSize = 8

    /// Hard-coded QR version: 125 modules
    let modules = 125

    /// Embeds fully self-contained, signed QR codes per tile into blue-channel LSBs.
    func embedTiledQR(in image: UIImage,
                      deviceID: String,
                      message:  String) -> UIImage? {

        guard let cg = image.cgImage else { return nil }
        let W = cg.width, H = cg.height
        let BPP = 4, BPR = W * BPP
        var pixels = [UInt8](repeating: 0, count: H * BPR)
        let cs = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(data: &pixels,
                                  width: W, height: H,
                                  bitsPerComponent: 8, bytesPerRow: BPR,
                                  space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))

        // Hard-coded tile geometry based on confirmed QR config
        let qrPix  = modules * blockSize
        let tilesX = W / qrPix
        let tilesY = H / qrPix

        print("Using QR with \(modules) modules (blockSize: \(blockSize)), grid \(tilesX)x\(tilesY)")

        // Tile loop
        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                let x0 = tx * qrPix
                let y0 = ty * qrPix

                // 1. Compute SHA-256 of upper 7 bits of all RGB pixels in tile
                var hasher = SHA256()
                for dy in 0..<qrPix {
                    let py = y0 + dy
                    for dx in 0..<qrPix {
                        let px = x0 + dx
                        let i = py * BPR + px * BPP
                        for c in 0..<3 {
                            hasher.update(data: [pixels[i + c] & 0xFE])
                        }
                    }
                }
                let hashHex = hasher.finalize()
                                    .map { String(format: "%02x", $0) }
                                    .joined()
                
                // 2. Build and sign payload
                var payload: [String: Any] = [
                    "device_id": deviceID,
                    "tile_id":   ty * tilesX + tx,
                    "tile_count": tilesX * tilesY,
                    "hash":     hashHex,
                    "message":  message
                ]

                let jsonToSign = try! JSONSerialization.data(withJSONObject: payload,
                                                             options: [.sortedKeys])
                let signature  = try! KeyManager.sign(data: jsonToSign)
                payload["sig"] = signature.map { String(format: "%02x", $0) }.joined()

                // 3. Encode payload into QR matrix
                let fullJSON = try! JSONSerialization.data(withJSONObject: payload)
                guard let qrMatrix = generateQRMatrix(from: fullJSON, modules: modules) else {
                    print("QR generation failed at tile (\(tx),\(ty))")
                    continue
                }

                // 4. Embed QR into blue channel LSBs (centered inside tile)
                for my in 0..<modules {
                    for mx in 0..<modules {
                        let bit = qrMatrix[my][mx]
                        for dy in 0..<blockSize {
                            for dx in 0..<blockSize {
                                let px = x0 + mx * blockSize + dx
                                let py = y0 + my * blockSize + dy
                                let i  = py * BPR + px * BPP
                                pixels[i + 2] = (pixels[i + 2] & 0xFE) | bit
                            }
                        }
                    }
                }
            }
        }

        // Return new image
        guard let outCG = CGContext(data: &pixels,
                                    width: W, height: H,
                                    bitsPerComponent: 8, bytesPerRow: BPR,
                                    space: cs,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?
                            .makeImage()
        else { return nil }

        return UIImage(cgImage: outCG)
    }

    /// Generates a QR matrix with a specific module count.
    private func generateQRMatrix(from data: Data,
                                  modules: Int) -> [[UInt8]]? {

        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ci = filter.outputImage else { return nil }

        // Scale to exactly match desired module size
        let scale      = CGFloat(modules) / ci.extent.width
        let transformed = ci.transformed(by: .init(scaleX: scale, y: scale))

        let ctx = CIContext()
        guard let cg = ctx.createCGImage(transformed, from: transformed.extent) else { return nil }

        var gray = [UInt8](repeating: 0, count: modules * modules)
        let gctx = CGContext(data: &gray,
                             width: modules, height: modules,
                             bitsPerComponent: 8, bytesPerRow: modules,
                             space: CGColorSpaceCreateDeviceGray(),
                             bitmapInfo: 0)!
        gctx.draw(cg, in: CGRect(x: 0, y: 0,
                                 width: modules, height: modules))

        return (0..<modules).map { y in
            (0..<modules).map { x in
                gray[y * modules + x] < 128 ? 1 : 0
            }
        }
    }
}
