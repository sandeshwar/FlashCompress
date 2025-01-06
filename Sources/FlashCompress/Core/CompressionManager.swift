import Foundation
import Metal

/// Manages the compression and decompression operations
final class CompressionManager {
    static let shared = CompressionManager()
    
    private let metalPipeline: MetalPipelineManager
    private let fileManager: FileManager
    private let chunkSize = 1024 * 1024 // 1MB chunks
    
    private init() {
        self.metalPipeline = .shared
        self.fileManager = .default
    }
    
    /// Compresses a file using GPU acceleration
    func compressFile(
        at sourceURL: URL,
        to destinationURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let inputStream = InputStream(url: sourceURL) else {
            completion(.failure(CompressionError.inputStreamCreationFailed))
            return
        }
        
        guard let outputStream = OutputStream(url: destinationURL, append: false) else {
            completion(.failure(CompressionError.outputStreamCreationFailed))
            return
        }
        
        inputStream.open()
        outputStream.open()
        
        defer {
            inputStream.close()
            outputStream.close()
        }
        
        let fileSize = (try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        var totalBytesProcessed = 0
        
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        
        func processNextChunk() {
            let bytesRead = inputStream.read(&buffer, maxLength: chunkSize)
            
            if bytesRead < 0 {
                completion(.failure(CompressionError.readError))
                return
            }
            
            if bytesRead == 0 {
                completion(.success(destinationURL))
                return
            }
            
            compressChunk(
                Array(buffer.prefix(bytesRead)),
                completion: { result in
                    switch result {
                    case .success(let compressedData):
                        let written = outputStream.write(compressedData, maxLength: compressedData.count)
                        if written < 0 {
                            completion(.failure(CompressionError.writeError))
                            return
                        }
                        
                        totalBytesProcessed += bytesRead
                        progress(Double(totalBytesProcessed) / Double(fileSize))
                        
                        processNextChunk()
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            )
        }
        
        processNextChunk()
    }
    
    /// Compresses a single chunk of data using Metal
    private func compressChunk(
        _ data: [UInt8],
        completion: @escaping (Result<[UInt8], Error>) -> Void
    ) {
        guard let inputBuffer = metalPipeline.makeBuffer(data),
              let outputBuffer = metalPipeline.makeBuffer(length: data.count) else {
            completion(.failure(CompressionError.bufferCreationFailed))
            return
        }
        
        var params = CompressionParams(
            inputLength: UInt32(data.count),
            dictionarySize: 4096,
            windowSize: 32768
        )
        
        guard let paramsBuffer = metalPipeline.makeBuffer([params]) else {
            completion(.failure(CompressionError.bufferCreationFailed))
            return
        }
        
        metalPipeline.execute(
            kernel: "compressBlock",
            buffers: [inputBuffer, outputBuffer, paramsBuffer],
            threadCount: data.count
        ) { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let ptr = outputBuffer.contents().assumingMemoryBound(to: UInt8.self)
            let compressedData = Array(UnsafeBufferPointer(start: ptr, count: data.count))
            completion(.success(compressedData))
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
        }
    }
}

/// Structure to hold compression parameters for Metal kernels
struct CompressionParams {
    let inputLength: UInt32
    let dictionarySize: UInt32
    let windowSize: UInt32
}
