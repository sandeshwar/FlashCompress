#import "CompressionEngine.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <vector>
#include <string>
#include <iostream>

static constexpr size_t THREAD_GROUP_SIZE = 256;

CompressionEngine::CompressionEngine() {
    device = MTLCreateSystemDefaultDevice();
    if (!device) {
        throw std::runtime_error("Failed to create Metal device");
    }
    
    commandQueue = [device newCommandQueue];
    if (!commandQueue) {
        throw std::runtime_error("Failed to create command queue");
    }
    
    NSError* error = nil;
    library = [device newDefaultLibrary];
    if (!library) {
        throw std::runtime_error("Failed to create default library");
    }
    
    compressFunction = [library newFunctionWithName:@"compress"];
    decompressFunction = [library newFunctionWithName:@"decompress"];
    if (!compressFunction || !decompressFunction) {
        throw std::runtime_error("Failed to load Metal functions");
    }
    
    error = nil;
    compressPipeline = [device newComputePipelineStateWithFunction:compressFunction error:&error];
    if (!compressPipeline) {
        throw std::runtime_error("Failed to create compress pipeline state");
    }
    
    error = nil;
    decompressPipeline = [device newComputePipelineStateWithFunction:decompressFunction error:&error];
    if (!decompressPipeline) {
        throw std::runtime_error("Failed to create decompress pipeline state");
    }
}

CompressionEngine::~CompressionEngine() {
}

std::vector<uint8_t> CompressionEngine::compress(const std::vector<uint8_t>& input) {
    @autoreleasepool {
        size_t input_size = input.size();
        
        // Create buffers
        id<MTLBuffer> inputBuffer = [device newBufferWithBytes:input.data()
                                                      length:input_size
                                                     options:MTLResourceStorageModeShared];
        
        id<MTLBuffer> outputBuffer = [device newBufferWithLength:input_size * 2
                                                       options:MTLResourceStorageModeShared];
        
        id<MTLBuffer> matchLengthsBuffer = [device newBufferWithLength:input_size * sizeof(uint32_t)
                                                             options:MTLResourceStorageModeShared];
        
        id<MTLBuffer> matchPositionsBuffer = [device newBufferWithLength:input_size * sizeof(uint32_t)
                                                                options:MTLResourceStorageModeShared];
        
        id<MTLBuffer> outputSizeBuffer = [device newBufferWithLength:sizeof(uint32_t)
                                                           options:MTLResourceStorageModeShared];

        id<MTLBuffer> inputSizeBuffer = [device newBufferWithBytes:&input_size
                                                          length:sizeof(uint32_t)
                                                         options:MTLResourceStorageModeShared];
        
        // Initialize output size to 0
        uint32_t initial_output_size = 0;
        memcpy([outputSizeBuffer contents], &initial_output_size, sizeof(uint32_t));
        
        // Create command buffer and encoder
        id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
        id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
        
        // Configure pipeline
        [computeEncoder setComputePipelineState:compressPipeline];
        
        // Set buffers
        [computeEncoder setBuffer:inputBuffer offset:0 atIndex:0];
        [computeEncoder setBuffer:outputBuffer offset:0 atIndex:1];
        [computeEncoder setBuffer:matchLengthsBuffer offset:0 atIndex:2];
        [computeEncoder setBuffer:matchPositionsBuffer offset:0 atIndex:3];
        [computeEncoder setBuffer:outputSizeBuffer offset:0 atIndex:4];
        [computeEncoder setBuffer:inputSizeBuffer offset:0 atIndex:5];
        
        // Calculate grid size
        NSUInteger gridSize = (input_size + THREAD_GROUP_SIZE - 1) / THREAD_GROUP_SIZE * THREAD_GROUP_SIZE;
        MTLSize threadGroupSize = MTLSizeMake(THREAD_GROUP_SIZE, 1, 1);
        MTLSize gridDimension = MTLSizeMake(gridSize, 1, 1);
        
        // Dispatch
        [computeEncoder dispatchThreads:gridDimension threadsPerThreadgroup:threadGroupSize];
        [computeEncoder endEncoding];
        
        // Execute and wait
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];
        
        // Get output size
        uint32_t output_size = *static_cast<uint32_t*>([outputSizeBuffer contents]);
        
        // Copy result
        std::vector<uint8_t> result(output_size);
        memcpy(result.data(), [outputBuffer contents], output_size);
        
        return result;
    }
}

std::vector<uint8_t> CompressionEngine::decompress(const std::vector<uint8_t>& input) {
    @autoreleasepool {
        size_t input_size = input.size();
        size_t max_output_size = input_size * 4; // Conservative estimate
        
        // Create buffers
        id<MTLBuffer> inputBuffer = [device newBufferWithBytes:input.data()
                                                      length:input_size
                                                     options:MTLResourceStorageModeShared];
        
        id<MTLBuffer> outputBuffer = [device newBufferWithLength:max_output_size
                                                       options:MTLResourceStorageModeShared];
        
        id<MTLBuffer> outputSizeBuffer = [device newBufferWithLength:sizeof(uint32_t)
                                                           options:MTLResourceStorageModeShared];

        id<MTLBuffer> inputSizeBuffer = [device newBufferWithBytes:&input_size
                                                          length:sizeof(uint32_t)
                                                         options:MTLResourceStorageModeShared];
        
        // Initialize output size to 0
        uint32_t initial_output_size = 0;
        memcpy([outputSizeBuffer contents], &initial_output_size, sizeof(uint32_t));
        
        // Create command buffer and encoder
        id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
        id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
        
        // Configure pipeline
        [computeEncoder setComputePipelineState:decompressPipeline];
        
        // Set buffers
        [computeEncoder setBuffer:inputBuffer offset:0 atIndex:0];
        [computeEncoder setBuffer:outputBuffer offset:0 atIndex:1];
        [computeEncoder setBuffer:outputSizeBuffer offset:0 atIndex:2];
        [computeEncoder setBuffer:inputSizeBuffer offset:0 atIndex:3];
        
        // Calculate grid size
        NSUInteger gridSize = (input_size + THREAD_GROUP_SIZE - 1) / THREAD_GROUP_SIZE * THREAD_GROUP_SIZE;
        MTLSize threadGroupSize = MTLSizeMake(THREAD_GROUP_SIZE, 1, 1);
        MTLSize gridDimension = MTLSizeMake(gridSize, 1, 1);
        
        // Dispatch
        [computeEncoder dispatchThreads:gridDimension threadsPerThreadgroup:threadGroupSize];
        [computeEncoder endEncoding];
        
        // Execute and wait
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];
        
        // Get output size
        uint32_t output_size = *static_cast<uint32_t*>([outputSizeBuffer contents]);
        
        // Copy result
        std::vector<uint8_t> result(output_size);
        memcpy(result.data(), [outputBuffer contents], output_size);
        
        return result;
    }
}
