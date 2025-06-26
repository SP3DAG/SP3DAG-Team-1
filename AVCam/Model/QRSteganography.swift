import UIKit
import CoreImage
import CoreGraphics

struct QRSteganography {
    
    // MARK: – Public interface
    let blockSize: Int
    
    /// Generates a fixed 47 × 47 binary matrix (UInt8 0/1) from plain text.
    func generateQRMatrix(from text: String) -> [[UInt8]] {
        let data = text.data(using: .isoLatin1)!
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let ci = filter.outputImage else { return [[]] }
        let scale = floor(47.0 / ci.extent.width)
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent),
              cg.width == 47, cg.height == 47 else { return [[]] }
        
        var gray = [UInt8](repeating: 0, count: 47*47)
        let gctx = CGContext(data: &gray,
                             width: 47, height: 47,
                             bitsPerComponent: 8, bytesPerRow: 47,
                             space: CGColorSpaceCreateDeviceGray(),
                             bitmapInfo: 0)!
        gctx.draw(cg, in: CGRect(x: 0, y: 0, width: 47, height: 47))
        
        var result = [[UInt8]](repeating: [UInt8](repeating: 0, count: 47), count: 47)
        for y in 0..<47 {
            for x in 0..<47 {
                result[y][x] = gray[y * 47 + x] < 128 ? 1 : 0
            }
        }
        return result
    }
    
    /// Flattens a 2-D QR matrix row-wise to `Data` (1 byte per bit).
    func flattenQRMatrix(_ m: [[UInt8]]) -> Data { Data(m.flatMap { $0 }) }
    
    
    /// Embed one or more distinct QRs (with repeated tiles) into the image.
    ///
    /// - Parameters:
    ///   - image:    carrier image
    ///   - qrTexts:  array of distinct payload strings
    ///   - deviceID: UTF-8 device identifier (must match backend’s public key)
    ///   - spacing:  pixel spacing between tiles
    ///
    /// - Returns: new `UIImage` on success, else `nil`.
    func embedMultipleQRsInBlueChannel(image: UIImage,
                                       qrTexts: [String],
                                       deviceID: String,
                                       spacing: Double = 20.0) -> UIImage? {
        
        // Carrier image buffer
        guard let cgImage = image.cgImage else { return nil }
        let width  = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow   = width * bytesPerPixel
        
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let ctx = CGContext(data: &pixelData,
                            width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                            space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Convenience helpers
        func bits8 (_ v: UInt8 ) -> [UInt8] { (0..<8) .map { UInt8((v >> (7-$0)) & 1) } }
        func bits16(_ v: UInt16) -> [UInt8] { (0..<16).map { UInt8((v >> (15-$0)) & 1) } }
        
        let deviceIDBytes = [UInt8](deviceID.utf8)
        let devIDLenBits  = bits8(UInt8(deviceIDBytes.count))
        let devIDBits     = deviceIDBytes.flatMap { bits8($0) }
        
        // Determine QR pixel dimensions
        guard let firstMatrix = qrTexts.first.flatMap(generateQRMatrix),
              !firstMatrix.isEmpty else { return nil }
        
        let qrMod   = firstMatrix.count
        let qrPix   = qrMod * blockSize
        let spacer  = 1
        
        // To estimate the metadata height we need the signature length.
        // ECDSA P-256 r||s is 64 bytes, wrapped in DER (~72 bytes).  We conservatively
        // assume 80 bytes → 80*8 = 640 bits  ➜ 640 / qrPix rows.
        let worstSigBits = 640
        let worstFullBits = devIDLenBits.count + devIDBits.count +
        16 + 16 + 8 + worstSigBits            // totalTiles+index+sig
        let worstSigRows  = Int(ceil(Double(worstFullBits) / Double(qrPix)))
        let tileHeight    = qrPix + spacer + worstSigRows        // pixel rows per tile
        let tileWidth     = qrPix                                // pixel cols per tile
        
        // How many tiles fit?
        let tilesPerRow = Int( floor((Double(width)  + spacing) /
                                     (Double(tileWidth) + spacing)) )
        let tilesPerCol = Int( floor((Double(height) + spacing) /
                                     (Double(tileHeight) + spacing)) )
        
        guard tilesPerRow > 0, tilesPerCol > 0 else { return nil }
        
        let totalTiles = UInt16(tilesPerRow * tilesPerCol * qrTexts.count)
        let totalBits16 = bits16(totalTiles)
        
        // Start tiling
        var globalIndex: UInt16 = 0
        
        for text in qrTexts {
            let qrMatrix = generateQRMatrix(from: text)
            guard !qrMatrix.isEmpty else { continue }
            let flattened = flattenQRMatrix(qrMatrix)
            
            for row in 0..<tilesPerCol {
                let offsetY = Int(round(Double(row) * (Double(tileHeight) + spacing)))
                
                for col in 0..<tilesPerRow {
                    let offsetX = Int(round(Double(col) * (Double(tileWidth) + spacing)))
                    
                    // Metadata unique to this tile
                    let idx      = globalIndex;  globalIndex += 1
                    let idxBits  = bits16(idx)
                    
                    // Signature input = bitmap || deviceID || totalTiles || qr_index
                    var sigInput = Data(flattened)
                    sigInput.append(deviceIDBytes, count: deviceIDBytes.count)
                    sigInput.append(contentsOf: withUnsafeBytes(of: totalTiles.bigEndian, Array.init))
                    sigInput.append(contentsOf: withUnsafeBytes(of: idx.bigEndian,        Array.init))
                    
                    guard let signature = try? KeyManager.sign(data: sigInput) else { continue }
                    let sigLen = UInt8(signature.count)
                    let sigLenBits = bits8(sigLen)
                    let sigBits    = signature.flatMap(bits8)
                    
                    let fullBits = devIDLenBits + devIDBits +
                    totalBits16   + idxBits +
                    sigLenBits    + sigBits
                    
                    // Actual rows for this tile (may be less than worst-case)
                    let sigRows = Int(ceil(Double(fullBits.count) / Double(qrPix)))
                    
                    // Embed QR bitmap
                    for y in 0..<qrMod {
                        for x in 0..<qrMod {
                            let bit = qrMatrix[y][x]
                            for dy in 0..<blockSize {
                                for dx in 0..<blockSize {
                                    let px = offsetX + x*blockSize + dx
                                    let py = offsetY + y*blockSize + dy
                                    let idx = py*bytesPerRow + px*bytesPerPixel
                                    pixelData[idx+2] = (pixelData[idx+2] & 0xFE) | UInt8(bit)
                                }
                            }
                        }
                    }
                    
                    // Embed metadata bits
                    var bitPtr = 0
                    let metaStartY = offsetY + qrPix + spacer
                    for py in 0..<sigRows {
                        for px in 0..<qrPix {
                            guard bitPtr < fullBits.count else { break }
                            let x = offsetX + px
                            let y = metaStartY + py
                            let idx = y*bytesPerRow + x*bytesPerPixel
                            pixelData[idx+2] = (pixelData[idx+2] & 0xFE) | fullBits[bitPtr]
                            bitPtr += 1
                        }
                    }
                }
            }
        }
        
        // Produce UIImage
        guard let newCG = CGContext(data: &pixelData,
                                    width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            .makeImage()
        else { return nil }
        
        return UIImage(cgImage: newCG)
    }
}
