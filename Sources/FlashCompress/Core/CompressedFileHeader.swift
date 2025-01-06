import Foundation

/// Structure to represent the compressed file header
struct CompressedFileHeader {
    static let signature = "FZIP"
    static let currentVersion: UInt32 = 1
    
    let signature: String      // "FZIP"
    let version: UInt32       // File format version
    let windowSize: UInt32    // LZ77 window size
    let minMatchLength: UInt32 // Minimum match length
    let maxMatchLength: UInt32 // Maximum match length
    let dictionarySize: UInt32 // Dictionary size
    
    func write(to stream: OutputStream) -> Bool {
        // Write signature
        let signatureData = Array(signature.utf8)
        guard stream.write(signatureData, maxLength: signatureData.count) == signatureData.count else {
            return false
        }
        
        // Write version and parameters
        let values: [UInt32] = [version, windowSize, minMatchLength, maxMatchLength, dictionarySize]
        for value in values {
            var littleEndian = value.littleEndian
            let data = withUnsafeBytes(of: &littleEndian) { Array($0) }
            guard stream.write(data, maxLength: data.count) == data.count else {
                return false
            }
        }
        
        return true
    }
}
