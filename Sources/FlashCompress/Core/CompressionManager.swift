import Foundation
import Metal

/// Manages the compression and decompression operations
public final class CompressionManager {
    static let shared = CompressionManager()
    
    private let metalPipeline: MetalPipelineManager
    private let fileManager: FileManager
    private let chunkSize = 1024 * 1024 // 1MB chunks
    
    // Compression parameters
    private let windowSize: UInt32 = 32768    // 32KB sliding window
    private let minMatchLength: UInt32 = 3     // Minimum match length for LZ77
    private let maxMatchLength: UInt32 = 258   // Maximum match length
    private let dictionarySize: UInt32 = 4096  // Dictionary size for compression
    
    private init() {
        self.metalPipeline = .shared
        self.fileManager = .default
    }
    
    /// Compresses a file using GPU acceleration
    func compressFile(
        at sourceURL: URL,
        to destinationURL: URL,
        progress: @escaping (Double) -> Void
    ) async throws {
        guard let inputStream = InputStream(url: sourceURL) else {
            throw CompressionError.inputStreamCreationFailed
        }
        
        // Create output stream and ensure the directory exists
        let directory = destinationURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw CompressionError.outputStreamCreationFailed
        }
        
        guard let outputStream = OutputStream(url: destinationURL, append: false) else {
            throw CompressionError.outputStreamCreationFailed
        }
        
        inputStream.open()
        outputStream.open()
        
        defer {
            inputStream.close()
            outputStream.close()
        }
        
        // Get file size for progress tracking
        let fileSize = (try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        var totalBytesProcessed = 0
        
        // Write file header
        let header = CompressedFileHeader(
            signature: CompressedFileHeader.signature,
            version: CompressedFileHeader.currentVersion,
            windowSize: windowSize,
            minMatchLength: minMatchLength,
            maxMatchLength: maxMatchLength,
            dictionarySize: dictionarySize
        )
        
        guard header.write(to: outputStream) else {
            throw CompressionError.writeError
        }
        
        // Process file in chunks
        while true {
            var buffer = [UInt8](repeating: 0, count: chunkSize)
            let bytesRead = inputStream.read(&buffer, maxLength: chunkSize)
            
            if bytesRead < 0 {
                throw CompressionError.readError
            }
            
            if bytesRead == 0 {
                break
            }
            
            let chunk = Array(buffer.prefix(bytesRead))
            let compressedData = try await compressChunk(chunk)
            
            // Write compressed size first (4 bytes)
            var size = UInt32(compressedData.count).littleEndian
            let sizeData = withUnsafeBytes(of: &size) { Array($0) }
            
            guard outputStream.write(sizeData, maxLength: sizeData.count) == sizeData.count else {
                throw CompressionError.writeError
            }
            
            let written = outputStream.write(compressedData, maxLength: compressedData.count)
            if written < 0 {
                throw CompressionError.writeError
            }
            
            totalBytesProcessed += bytesRead
            progress(Double(totalBytesProcessed) / Double(fileSize))
        }
    }
    
    /// Compresses a single chunk of data using Metal
    private func compressChunk(_ data: [UInt8]) async throws -> [UInt8] {
        // Create aligned buffers
        guard let inputBuffer = metalPipeline.makeBuffer(data),
              let outputBuffer = metalPipeline.makeBuffer(length: data.count * 2 + 256), // Extra space for metadata
              let outputSizeBuffer = metalPipeline.makeBuffer(length: MemoryLayout<UInt32>.stride) else {
            throw CompressionError.bufferCreationFailed
        }
        
        // Initialize output size to 0 with proper alignment
        let outputSizePtr = outputSizeBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        outputSizePtr.pointee = 0
        
        let params = CompressionParams(
            inputLength: UInt32(data.count),
            dictionarySize: dictionarySize,
            windowSize: windowSize,
            minMatchLength: minMatchLength,
            maxMatchLength: maxMatchLength
        )
        
        // Create aligned params buffer
        guard let paramsBuffer = metalPipeline.makeBuffer(length: MemoryLayout<CompressionParams>.stride) else {
            throw CompressionError.bufferCreationFailed
        }
        
        // Copy params with proper alignment
        paramsBuffer.contents().bindMemory(to: CompressionParams.self, capacity: 1).pointee = params
        
        return try await withCheckedThrowingContinuation { continuation in
            metalPipeline.execute(
                kernel: "compressBlock",
                buffers: [inputBuffer, outputBuffer, paramsBuffer, outputSizeBuffer],
                threadCount: data.count
            ) { error in
                // Clean up buffers
                defer {
                    inputBuffer.setPurgeableState(.empty)
                    outputBuffer.setPurgeableState(.empty)
                    paramsBuffer.setPurgeableState(.empty)
                    outputSizeBuffer.setPurgeableState(.empty)
                }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Read the compressed size
                let compressedSize = outputSizePtr.pointee
                
                // Read the compressed data
                let outputPtr = outputBuffer.contents().bindMemory(to: UInt8.self, capacity: Int(compressedSize))
                let compressedData = Array(UnsafeBufferPointer(start: outputPtr, count: Int(compressedSize)))
                
                continuation.resume(returning: compressedData)
            }
        }
    }
}

/// Compression-related errors
enum CompressionError: LocalizedError {
    case inputStreamCreationFailed
    case outputStreamCreationFailed
    case readError
    case writeError
    case bufferCreationFailed
    case metalError(String)
    
    var errorDescription: String? {
        switch self {
        case .inputStreamCreationFailed:
            return "Failed to create input stream"
        case .outputStreamCreationFailed:
            return "Failed to create output stream"
        case .readError:
            return "Error reading from input stream"
        case .writeError:
            return "Error writing to output stream"
        case .bufferCreationFailed:
            return "Failed to create Metal buffer"
        case .metalError(let message):
            return "Metal error: \(message)"
        }
    }
}
