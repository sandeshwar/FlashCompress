import XCTest
@testable import FlashCompress

final class MetalTests: XCTestCase {
    let metalPipeline = MetalPipelineManager.shared
    
    func testMetalPipelineInitialization() {
        // Verify that we can create compute pipeline for our kernel
        let mirror = Mirror(reflecting: metalPipeline)
        if let computePipelineStates = mirror.children.first(where: { $0.label == "computePipelineStates" })?.value as? [String: Any] {
            XCTAssertTrue(computePipelineStates.keys.contains("compressBlock"))
        } else {
            XCTFail("Could not access compute pipeline states")
        }
    }
    
    func testBufferCreation() {
        let testData: [UInt8] = Array(0...255)
        
        // Test creating buffer from data
        guard let buffer = metalPipeline.makeBuffer(testData) else {
            XCTFail("Failed to create buffer from data")
            return
        }
        
        // Verify buffer contents using withUnsafeBytes for safety
        let bufferData = buffer.contents().withMemoryRebound(to: UInt8.self, capacity: testData.count) { ptr in
            Array(UnsafeBufferPointer(start: ptr, count: testData.count))
        }
        XCTAssertEqual(bufferData, testData)
        
        // Test creating empty buffer
        let size = 1024
        guard let emptyBuffer = metalPipeline.makeBuffer(length: size) else {
            XCTFail("Failed to create empty buffer")
            return
        }
        
        XCTAssertEqual(emptyBuffer.length, size)
    }
    
    func testKernelExecution() {
        let expectation = XCTestExpectation(description: "Kernel execution")
        let testData: [UInt8] = Array(repeating: 65, count: 1024) // 1KB of 'A' characters
        
        guard let inputBuffer = metalPipeline.makeBuffer(testData),
              let outputBuffer = metalPipeline.makeBuffer(length: testData.count * 2 + 256),
              let outputSizeBuffer = metalPipeline.makeBuffer(length: MemoryLayout<UInt32>.stride) else {
            XCTFail("Failed to create buffers")
            return
        }
        
        // Initialize output size to 0
        let outputSizePtr = outputSizeBuffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        outputSizePtr.pointee = 0
        
        let params = CompressionParams(
            inputLength: UInt32(testData.count),
            dictionarySize: 4096,
            windowSize: 32768,
            minMatchLength: 3,
            maxMatchLength: 258
        )
        
        guard let paramsBuffer = metalPipeline.makeBuffer(length: MemoryLayout<CompressionParams>.stride) else {
            XCTFail("Failed to create params buffer")
            return
        }
        
        // Copy params with proper alignment
        paramsBuffer.contents().bindMemory(to: CompressionParams.self, capacity: 1).pointee = params
        
        metalPipeline.execute(
            kernel: "compressBlock",
            buffers: [inputBuffer, outputBuffer, paramsBuffer, outputSizeBuffer],
            threadCount: testData.count
        ) { error in
            XCTAssertNil(error)
            
            // Verify that some compression happened
            let compressedSize = outputSizePtr.pointee
            XCTAssertGreaterThan(compressedSize, 0)
            XCTAssertLessThanOrEqual(compressedSize, UInt32(testData.count * 2))
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
