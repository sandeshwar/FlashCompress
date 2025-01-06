import Foundation
import Metal
import FlashCompress

/// Manages Metal resources and pipeline states
final class MetalPipelineManager {
    static let shared = MetalPipelineManager()
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var computePipelineStates: [String: MTLComputePipelineState] = [:]
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue")
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        setupPipelines()
    }
    
    private func setupPipelines() {
        // First try to load from the default library
        if let defaultLibrary = device.makeDefaultLibrary() {
            loadKernels(from: defaultLibrary)
            return
        }
        
        // If default library fails, try to load from the bundled metallib
        if let libraryURL = Bundle.module.url(forResource: "default", withExtension: "metallib", subdirectory: "Metal"),
           let library = try? device.makeLibrary(URL: libraryURL) {
            loadKernels(from: library)
            return
        }
        
        // If both methods fail, try to compile from source
        if let sourceURL = Bundle.module.url(forResource: "Kernels", withExtension: "metal", subdirectory: "Metal"),
           let source = try? String(contentsOf: sourceURL),
           let library = try? device.makeLibrary(source: source, options: nil) {
            loadKernels(from: library)
            return
        }
        
        print("Failed to load Metal library through any method")
    }
    
    private func loadKernels(from library: MTLLibrary) {
        let kernelNames = ["compressBlock"]
        
        for name in kernelNames {
            guard let function = library.makeFunction(name: name) else {
                print("Failed to create function for kernel: \(name)")
                continue
            }
            
            do {
                let pipelineState = try device.makeComputePipelineState(function: function)
                computePipelineStates[name] = pipelineState
            } catch {
                print("Failed to create pipeline state for kernel: \(name), error: \(error)")
            }
        }
    }
    
    /// Creates a Metal buffer from data
    func makeBuffer<T>(_ data: [T], options: MTLResourceOptions = []) -> MTLBuffer? {
        return data.withUnsafeBytes { ptr in
            device.makeBuffer(bytes: ptr.baseAddress!, length: ptr.count, options: options)
        }
    }
    
    /// Creates an empty Metal buffer
    func makeBuffer(length: Int, options: MTLResourceOptions = []) -> MTLBuffer? {
        return device.makeBuffer(length: length, options: options)
    }
    
    /// Executes a Metal compute kernel
    func execute(
        kernel: String,
        buffers: [MTLBuffer],
        threadCount: Int,
        completion: @escaping (Error?) -> Void
    ) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipelineState = computePipelineStates[kernel] else {
            completion(FlashCompressError.commandCreationFailed)
            return
        }
        
        computeEncoder.setComputePipelineState(pipelineState)
        
        // Set buffers
        for (index, buffer) in buffers.enumerated() {
            computeEncoder.setBuffer(buffer, offset: 0, index: index)
        }
        
        // Calculate thread groups
        let maxThreadsPerGroup = pipelineState.maxTotalThreadsPerThreadgroup
        let threadsPerGroup = min(maxThreadsPerGroup, threadCount)
        let threadgroupsPerGrid = (threadCount + threadsPerGroup - 1) / threadsPerGroup
        
        let threadGroupSize = MTLSize(width: threadsPerGroup, height: 1, depth: 1)
        let threadGroups = MTLSize(width: threadgroupsPerGrid, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in
            completion(nil)
        }
        
        commandBuffer.commit()
    }
}
