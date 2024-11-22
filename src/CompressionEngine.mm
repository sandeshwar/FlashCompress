#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <vector>
#include <string>
#include <iostream>

class CompressionEngine {
private:
    id<MTLDevice> device;
    id<MTLLibrary> library;
    id<MTLCommandQueue> commandQueue;
    id<MTLFunction> compressFunction;
    id<MTLFunction> decompressFunction;
    
    static constexpr size_t THREAD_GROUP_SIZE = 256;
    
public:
    CompressionEngine() {
        // Get the default Metal device
        device = MTLCreateSystemDefaultDevice();
        if (!device) {
            throw std::runtime_error("Failed to create Metal device");
        }
        
        // Load Metal library containing our shader functions
        NSString* libraryPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"metallib"];
        NSURL *libraryURL = [NSURL fileURLWithPath:libraryPath];
        NSError* error = nil;
        library = [device newLibraryWithURL:libraryURL error:&error];
        if (!library) {
            throw std::runtime_error("Failed to load Metal library");
        }
        
        // Get function references
        compressFunction = [library newFunctionWithName:@"compress"];
        decompressFunction = [library newFunctionWithName:@"decompress"];
        if (!compressFunction || !decompressFunction) {
            throw std::runtime_error("Failed to load Metal functions");
        }
        
        // Create command queue
        commandQueue = [device newCommandQueue];
        if (!commandQueue) {
            throw std::runtime_error("Failed to create command queue");
        }
    }
    
    std::vector<uint8_t> compress(const std::vector<uint8_t>& input) {
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
            
            // Create command buffer and encoder
            id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
            id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
            
            // Configure pipeline
            NSError* error = nil;
            id<MTLComputePipelineState> pipelineState = [device newComputePipelineStateWithFunction:compressFunction
                                                                                             error:&error];
            [computeEncoder setComputePipelineState:pipelineState];
            
            // Set buffers
            [computeEncoder setBuffer:inputBuffer offset:0 atIndex:0];
            [computeEncoder setBuffer:outputBuffer offset:0 atIndex:1];
            [computeEncoder setBuffer:matchLengthsBuffer offset:0 atIndex:2];
            [computeEncoder setBuffer:matchPositionsBuffer offset:0 atIndex:3];
            [computeEncoder setBuffer:outputSizeBuffer offset:0 atIndex:4];
            
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
    
    std::vector<uint8_t> decompress(const std::vector<uint8_t>& input) {
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
            
            // Create command buffer and encoder
            id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
            id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
            
            // Configure pipeline
            NSError* error = nil;
            id<MTLComputePipelineState> pipelineState = [device newComputePipelineStateWithFunction:decompressFunction
                                                                                             error:&error];
            [computeEncoder setComputePipelineState:pipelineState];
            
            // Set buffers
            [computeEncoder setBuffer:inputBuffer offset:0 atIndex:0];
            [computeEncoder setBuffer:outputBuffer offset:0 atIndex:1];
            [computeEncoder setBuffer:outputSizeBuffer offset:0 atIndex:2];
            
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
};
