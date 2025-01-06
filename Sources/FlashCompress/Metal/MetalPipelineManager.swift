import Metal
import Foundation

/// Manages Metal compute pipelines for compression operations
final class MetalPipelineManager {
    static let shared = MetalPipelineManager()
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var computePipelineStates: [String: MTLComputePipelineState] = [:]
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("GPU not available")
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create command queue")
        }
        self.commandQueue = commandQueue
        
        setupPipelines()
    }
    
    private func setupPipelines() {
        guard let library = try? device.makeDefaultLibrary() else {
            fatalError("Could not create Metal library")
        }
        
        let kernelNames = ["compressBlock", "buildDictionary", "findPatterns"]
        
        for name in kernelNames {
            guard let function = library.makeFunction(name: name) else {
                fatalError("Could not create function \(name)")
            }
            
            do {
                let pipelineState = try device.makeComputePipelineState(function: function)
                computePipelineStates[name] = pipelineState
            } catch {
                fatalError("Could not create pipeline state for \(name): \(error)")
            }
        }
    }
    
    /// Creates a Metal buffer from data
    func makeBuffer<T>(_ data: [T], options: MTLResourceOptions = []) -> MTLBuffer? {
        let length = MemoryLayout<T>.stride * data.count
        return device.makeBuffer(bytes: data, length: length, options: options)
    }
    
    /// Creates an empty Metal buffer
    func makeBuffer(length: Int, options: MTLResourceOptions = []) -> MTLBuffer? {
        return device.makeBuffer(length: length, options: options)
    }
    
    /// Executes a compute kernel
    func execute(
        kernel: String,
        buffers: [MTLBuffer],
        threadCount: Int,
        completion: @escaping (Error?) -> Void
    ) {
        guard let pipelineState = computePipelineStates[kernel] else {
            completion(NSError(domain: "MetalPipeline", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid kernel name"]))
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            completion(NSError(domain: "MetalPipeline", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not create command buffer or encoder"]))
            return
        }
        
        computeEncoder.setComputePipelineState(pipelineState)
        
        for (index, buffer) in buffers.enumerated() {
            computeEncoder.setBuffer(buffer, offset: 0, index: index)
        }
        
        let threadExecutionWidth = pipelineState.threadExecutionWidth
        let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
        let threadgroupCount = (threadCount + threadExecutionWidth - 1) / threadExecutionWidth
        let threadgroups = MTLSize(width: threadgroupCount, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { buffer in
            completion(buffer.error)
        }
        
        commandBuffer.commit()
    }
}
