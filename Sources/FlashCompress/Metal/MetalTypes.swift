import Foundation

/// Structure to hold compression parameters with proper memory alignment
struct CompressionParams {
    let inputLength: UInt32
    let dictionarySize: UInt32
    let windowSize: UInt32
    let minMatchLength: UInt32
    let maxMatchLength: UInt32
    
    init(inputLength: UInt32, dictionarySize: UInt32, windowSize: UInt32, minMatchLength: UInt32, maxMatchLength: UInt32) {
        self.inputLength = inputLength
        self.dictionarySize = dictionarySize
        self.windowSize = windowSize
        self.minMatchLength = minMatchLength
        self.maxMatchLength = maxMatchLength
    }
}
