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
        
        do {
            try setupPipelines()
        } catch {
            print("Failed to setup Metal pipelines: \(error)")
            fatalError("Metal initialization failed")
        }
    }
    
    private func setupPipelines() throws {
        print("Setting up Metal pipelines...")
        
        // First try to load from the default library
        if let defaultLibrary = try? device.makeDefaultLibrary() {
            print("Successfully loaded default Metal library")
            try loadKernels(from: defaultLibrary)
            isLibraryLoaded = true
            return
        }
        print("Failed to load default Metal library, trying bundle...")
        
        // Try different bundle approaches
        let possibleBundles = [
            Bundle.main,
            Bundle.module,
            Bundle(for: type(of: self))
        ]
        
        for (index, bundle) in possibleBundles.enumerated() {
            print("Trying bundle \(index)...")
            
            // Try without subdirectory first
            if let libraryURL = bundle.url(forResource: "default", withExtension: "metallib") {
                print("Found metallib at: \(libraryURL)")
                do {
                    let library = try device.makeLibrary(URL: libraryURL)
                    try loadKernels(from: library)
                    isLibraryLoaded = true
                    return
                } catch {
                    print("Failed to load library from URL \(libraryURL): \(error)")
                }
            }
            
            // Try with Resources/Metal subdirectory
            if let libraryURL = bundle.url(forResource: "default", withExtension: "metallib", subdirectory: "Resources/Metal") {
                print("Found metallib in Resources/Metal at: \(libraryURL)")
                do {
                    let library = try device.makeLibrary(URL: libraryURL)
                    try loadKernels(from: library)
                    isLibraryLoaded = true
                    return
                } catch {
                    print("Failed to load library from Resources/Metal URL \(libraryURL): \(error)")
                }
            }
        }
        
        // If we get here, we failed to load the library
        print("Failed to find Metal library in any location")
        throw MetalError.libraryCreationFailed
    }
    
    private func loadKernels(from library: MTLLibrary) throws {
        print("Loading kernels from library...")
        let kernelNames = ["compressBlock"]
        
        for name in kernelNames {
            print("Creating function for kernel: \(name)")
            guard let function = library.makeFunction(name: name) else {
                print("Failed to create function for kernel: \(name)")
                throw MetalError.functionCreationFailed
            }
            
            do {
                print("Creating pipeline state for kernel: \(name)")
                let pipelineState = try device.makeComputePipelineState(function: function)
                computePipelineStates[name] = pipelineState
                print("Successfully created pipeline state for kernel: \(name)")
            } catch {
                print("Failed to create pipeline state for kernel: \(name), error: \(error)")
                throw MetalError.pipelineCreationFailed
            }
        }
        print("Successfully loaded all kernels")
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

