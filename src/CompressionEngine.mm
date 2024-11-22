#import "CompressionEngine.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <vector>
#include <string>
#include <iostream>
#include <algorithm>

static constexpr size_t THREAD_GROUP_SIZE = 256;

CompressionEngine::CompressionEngine() {
    @autoreleasepool {
        // Print Metal availability information
        NSArray<id<MTLDevice>> *devices = MTLCopyAllDevices();
        if (devices && [devices count] > 0) {
            std::cout << "Available Metal devices:\n";
            for (id<MTLDevice> dev in devices) {
                std::cout << "  - " << [[dev name] UTF8String] << "\n";
            }
        } else {
            std::cerr << "No Metal devices found in the system\n";
        }

        // Try to get the first available device if default device fails
        device = MTLCreateSystemDefaultDevice();
        if (!device && devices && [devices count] > 0) {
            device = [devices firstObject];
            std::cout << "Using first available device: " << [[device name] UTF8String] << "\n";
        }
        
        if (!device) {
            std::cerr << "Metal device creation failed. Please ensure Metal is supported on your system.\n";
            throw std::runtime_error("Failed to create Metal device");
        }
        
        std::cout << "Metal device created: " << [[device name] UTF8String] << "\n";
        
        commandQueue = [device newCommandQueue];
        if (!commandQueue) {
            throw std::runtime_error("Failed to create command queue");
        }
        
        NSError* error = nil;
        NSString* executablePath = [[NSBundle mainBundle] executablePath];
        NSString* executableDir = [executablePath stringByDeletingLastPathComponent];
        NSURL* libraryURL = [NSURL fileURLWithPath:[executableDir stringByAppendingPathComponent:@"default.metallib"]];
        
        std::cout << "Looking for Metal library at: " << [libraryURL.path UTF8String] << "\n";
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:libraryURL.path]) {
            std::cout << "Metal library file exists\n";
            library = [device newLibraryWithURL:libraryURL error:&error];
        } else {
            std::cerr << "Metal library not found at path. Trying default library...\n";
            library = [device newDefaultLibrary];
        }
        
        if (!library) {
            std::cerr << "Failed to load Metal library. Error: " << (error ? [[error localizedDescription] UTF8String] : "Unknown error") << "\n";
            throw std::runtime_error("Failed to create Metal library");
        }
        
        std::cout << "Metal library loaded successfully\n";
        
        compressFunction = [library newFunctionWithName:@"compress"];
        decompressFunction = [library newFunctionWithName:@"decompress"];
        if (!compressFunction || !decompressFunction) {
            std::cerr << "Failed to load Metal functions. Please ensure the Metal shader code is correctly compiled.\n";
            throw std::runtime_error("Failed to load Metal functions");
        }
        
        error = nil;
        compressPipeline = [device newComputePipelineStateWithFunction:compressFunction error:&error];
        if (!compressPipeline) {
            std::cerr << "Failed to create compress pipeline state. Error: " << (error ? [[error localizedDescription] UTF8String] : "Unknown error") << "\n";
            throw std::runtime_error("Failed to create compress pipeline state");
        }
        
        error = nil;
        decompressPipeline = [device newComputePipelineStateWithFunction:decompressFunction error:&error];
        if (!decompressPipeline) {
            std::cerr << "Failed to create decompress pipeline state. Error: " << (error ? [[error localizedDescription] UTF8String] : "Unknown error") << "\n";
            throw std::runtime_error("Failed to create decompress pipeline state");
        }
    }
}

CompressionEngine::~CompressionEngine() {
    @autoreleasepool {
        if (decompressPipeline) [decompressPipeline release];
        if (compressPipeline) [compressPipeline release];
        if (decompressFunction) [decompressFunction release];
        if (compressFunction) [compressFunction release];
        if (library) [library release];
        if (commandQueue) [commandQueue release];
        if (device) [device release];
    }
}

std::vector<uint8_t> CompressionEngine::compress(const std::vector<uint8_t>& input) {
    @autoreleasepool {
        size_t input_size = input.size();
        std::cout << "Input size: " << input_size << " bytes\n";
        
        // Create buffers
        id<MTLBuffer> inputBuffer = [device newBufferWithBytes:input.data()
                                                      length:input_size
                                                     options:MTLResourceStorageModeShared];
        
        // Allocate enough space for the worst case (each byte becomes a literal)
        size_t max_output_size = input_size * 2;  // Each byte could need 2 bytes (flag + literal)
        std::cout << "Allocated output buffer size: " << max_output_size << " bytes\n";
        
        id<MTLBuffer> outputBuffer = [device newBufferWithLength:max_output_size
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
        
        std::cout << "Grid size: " << gridSize << ", Thread group size: " << THREAD_GROUP_SIZE << "\n";
        
        // First pass: Find matches
        [computeEncoder dispatchThreads:gridDimension threadsPerThreadgroup:threadGroupSize];
        [computeEncoder endEncoding];
        
        // Execute and wait
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];
        
        // Get output size
        uint32_t output_size = *static_cast<uint32_t*>([outputSizeBuffer contents]);
        std::cout << "Raw output size from GPU: " << output_size << " bytes\n";
        
        if (output_size == 0 || output_size > max_output_size) {
            std::cerr << "Invalid output size: " << output_size << " (max: " << max_output_size << ")\n";
            output_size = input_size;  // Fallback to uncompressed size
            
            // Copy input data as literal bytes
            uint8_t* output_data = static_cast<uint8_t*>([outputBuffer contents]);
            for (size_t i = 0; i < input_size; i++) {
                output_data[i * 2] = 0x00;  // Literal flag
                output_data[i * 2 + 1] = input[i];  // Literal byte
            }
            output_size = input_size * 2;
        }
        
        // Copy result
        std::vector<uint8_t> result(output_size);
        memcpy(result.data(), [outputBuffer contents], output_size);
        
        // Print first few bytes for debugging
        std::cout << "First 16 bytes of output: ";
        for (size_t i = 0; i < std::min(output_size, size_t(16)); i++) {
            printf("%02x ", result[i]);
        }
        std::cout << "\n";
        
        // Release buffers
        [inputBuffer release];
        [outputBuffer release];
        [matchLengthsBuffer release];
        [matchPositionsBuffer release];
        [outputSizeBuffer release];
        [inputSizeBuffer release];
        
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
        if (output_size == 0 || output_size > max_output_size) {
            throw std::runtime_error("Decompression failed: invalid output size");
        }
        
        // Copy result
        std::vector<uint8_t> result(output_size);
        memcpy(result.data(), [outputBuffer contents], output_size);
        
        // Release buffers
        [inputBuffer release];
        [outputBuffer release];
        [outputSizeBuffer release];
        [inputSizeBuffer release];
        
        return result;
    }
}
