import UIKit
import CoreImage
import CoreGraphics

struct QRSteganography {
    
    let blockSize: Int
    
    func generateQRMatrix(from text: String) -> [[UInt8]] {
        
        let desiredSide = 51
        var payload = text
        
        while true {
            
            // make the QR with CoreImage
            let data = payload.data(using: .isoLatin1)!
            let filter = CIFilter(name: "CIQRCodeGenerator")!
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("H",  forKey: "inputCorrectionLevel")
            
            guard let ci = filter.outputImage else { return [[]] }
            
            // No scaling
            let ctx = CIContext(options: [.outputPremultiplied: false])
            guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return [[]] }
            
            let side = cg.width
            
            if side == desiredSide {
                var gray = [UInt8](repeating: 0, count: side * side)
                let gctx = CGContext(data: &gray,
                                     width: side, height: side,
                                     bitsPerComponent: 8, bytesPerRow: side,
                                     space: CGColorSpaceCreateDeviceGray(),
                                     bitmapInfo: 0)!
                gctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
                
                return (0..<side).map { y in
                    (0..<side).map { x in gray[y * side + x] < 128 ? 1 : 0 }
                }
            }
            
            if side > desiredSide {
                fatalError("Payload too large – CIQRCodeGenerator chose side \(side) > \(desiredSide)")
            }
            
            // side < desiredSide  → pad and retry
            payload += "#"
        }
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
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let ctx = CGContext(data: &pixelData,
                            width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                            space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        func bits8(_ v: UInt8) -> [UInt8] { (0..<8).map { UInt8((v >> (7-$0)) & 1) } }
        func bits16(_ v: UInt16) -> [UInt8] { (0..<16).map { UInt8((v >> (15-$0)) & 1) } }
        
        let deviceIDBytes = [UInt8](deviceID.utf8)
        let devIDLenBits = bits8(UInt8(deviceIDBytes.count))
        let devIDBits = deviceIDBytes.flatMap { bits8($0) }
        
        guard let firstMatrix = qrTexts.first.flatMap(generateQRMatrix),
              !firstMatrix.isEmpty else { return nil }
        
        let qrMod = firstMatrix.count
        let qrPix = qrMod * blockSize
        let spacer = 1
        
        let worstSigBits = 640
        let worstFullBits = devIDLenBits.count + devIDBits.count + 16 + 16 + 8 + worstSigBits
        let worstSigRows = Int(ceil(Double(worstFullBits) / Double(qrPix)))
        let tileHeight = qrPix + spacer + worstSigRows
        let tileWidth = qrPix
        
        let tilesPerRow = Int(floor((Double(width) + spacing) / (Double(tileWidth) + spacing)))
        let tilesPerCol = Int(floor((Double(height) + spacing) / (Double(tileHeight) + spacing)))
        
        guard tilesPerRow > 0, tilesPerCol > 0 else { return nil }
        
        let totalTiles = UInt16(tilesPerRow * tilesPerCol * qrTexts.count)
        let totalBits16 = bits16(totalTiles)
        
        var globalIndex: UInt16 = 0
        
        for text in qrTexts {
            let qrMatrix = generateQRMatrix(from: text)
            guard !qrMatrix.isEmpty else { fatalError("QR generation failed") }
            let flattened = flattenQRMatrix(qrMatrix)
            
            for row in 0..<tilesPerCol {
                let offsetY = Int(round(Double(row) * (Double(tileHeight) + spacing)))
                
                for col in 0..<tilesPerRow {
                    let offsetX = Int(round(Double(col) * (Double(tileWidth) + spacing)))
                    
                    let idx = globalIndex; globalIndex += 1
                    let idxBits = bits16(idx)
                    
                    var sigInput = Data(flattened)
                    sigInput.append(deviceIDBytes, count: deviceIDBytes.count)
                    sigInput.append(contentsOf: withUnsafeBytes(of: totalTiles.bigEndian, Array.init))
                    sigInput.append(contentsOf: withUnsafeBytes(of: idx.bigEndian, Array.init))
                    
                    guard let signature = try? KeyManager.sign(data: sigInput) else { continue }
                    let sigLen = UInt8(signature.count)
                    let sigLenBits = bits8(sigLen)
                    let sigBits = signature.flatMap(bits8)
                    
                    let fullBits = devIDLenBits + devIDBits + totalBits16 + idxBits + sigLenBits + sigBits
                    let sigRows = Int(ceil(Double(fullBits.count) / Double(qrPix)))
                    
                    for y in 0..<qrMod {
                        for x in 0..<qrMod {
                            let bit = qrMatrix[y][x]
                            for dy in 0..<blockSize {
                                for dx in 0..<blockSize {
                                    let px = offsetX + x*blockSize + dx
                                    let py = offsetY + y*blockSize + dy
                                    let i = py*bytesPerRow + px*bytesPerPixel
                                    pixelData[i+2] = (pixelData[i+2] & 0xFE) | UInt8(bit)
                                }
                            }
                        }
                    }
                    
                    var bitPtr = 0
                    let metaStartY = offsetY + qrPix + spacer
                    for py in 0..<sigRows {
                        for px in 0..<qrPix {
                            guard bitPtr < fullBits.count else { break }
                            let x = offsetX + px
                            let y = metaStartY + py
                            let i = y*bytesPerRow + x*bytesPerPixel
                            pixelData[i+2] = (pixelData[i+2] & 0xFE) | fullBits[bitPtr]
                            bitPtr += 1
                        }
                    }
                }
            }
        }
        
        guard let newCG = CGContext(data: &pixelData,
                                    width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage() else { return nil }
        
        return UIImage(cgImage: newCG)
    }
}
