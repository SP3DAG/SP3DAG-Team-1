import CryptoKit   // SHA-256

/// SHA-256 over the 7-MSBs of **all three RGB channels** inside the rectangle
///   [x, y, width, height]
/// The blue-channel LSB is *not yet* overwritten when you call this function.
func hashSevenMSBsRGB(x: Int, y: Int,
                      width: Int, height: Int,
                      bytesPerRow: Int,
                      pixelData: UnsafePointer<UInt8>) -> Data
{
    var hasher = SHA256()
    
    for py in 0..<height {
        let rowPtr = pixelData.advanced(by: (y + py) * bytesPerRow)
        
        for px in 0..<width {
            let base = (x + px) * 4           // RGBA interleaved
            hasher.update(data: [ rowPtr[base    ] & 0xFE ])  // Red
            hasher.update(data: [ rowPtr[base + 1] & 0xFE ])  // Green
            hasher.update(data: [ rowPtr[base + 2] & 0xFE ])  // Blue
        }
    }
    return Data(hasher.finalize())            // 32 bytes
}
