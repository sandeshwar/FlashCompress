import Foundation
import Metal

/// Manages Metal resources and pipeline states
public final class MetalPipelineManager {
    public static let shared = MetalPipelineManager()
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var computePipelineStates: [String: MTLComputePipelineState] = [:]
    private var isLibraryLoaded = false
    
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
            isLibraryLoaded = true
            return
        }
        
        // If default library fails, try to load from the bundle
        if let bundleURL = Bundle.module.url(forResource: "default", withExtension: "metallib"),
           let library = try? device.makeLibrary(URL: bundleURL) {
            loadKernels(from: library)
            isLibraryLoaded = true
        }
        
        print("Failed to load Metal library")
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
    public func makeBuffer<T>(_ data: [T], options: MTLResourceOptions = []) -> MTLBuffer? {
        guard isLibraryLoaded else { return nil }
        return data.withUnsafeBytes { ptr in
            device.makeBuffer(bytes: ptr.baseAddress!, length: ptr.count, options: options)
        }
    }
    
    /// Creates an empty Metal buffer
    public func makeBuffer(length: Int, options: MTLResourceOptions = []) -> MTLBuffer? {
        guard isLibraryLoaded else { return nil }
        return device.makeBuffer(length: length, options: options)
    }
    
    /// Executes a Metal compute kernel
    public func execute(
        kernel: String,
        buffers: [MTLBuffer],
        threadCount: Int,
        completion: @escaping (Error?) -> Void
    ) {
        guard isLibraryLoaded else {
            completion(MetalError.libraryNotLoaded)
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipelineState = computePipelineStates[kernel] else {
            completion(MetalError.commandCreationFailed)
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

