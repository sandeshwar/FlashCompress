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
        @autoreleasepool {
            NSLog(@"Initializing Metal device...");
            
            // Get all available Metal devices
            NSArray<id<MTLDevice>> *devices = MTLCopyAllDevices();
            if ([devices count] == 0) {
                NSLog(@"No Metal devices found on the system");
                throw std::runtime_error("No Metal devices found");
            }
            
            // Use the first available device
            device = [devices firstObject];
            if (!device) {
                NSLog(@"Failed to get Metal device");
                throw std::runtime_error("Failed to get Metal device");
            }
            
            NSLog(@"Successfully created Metal device: %@", [device name]);
            NSLog(@"Device supports unified memory: %d", [device hasUnifiedMemory]);
            NSLog(@"Device maximum buffer length: %lu", (unsigned long)[device maxBufferLength]);
            
            NSError* error = nil;
            
            // First try loading from the main bundle
            NSString* libraryPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"metallib"];
            NSLog(@"Attempting to load Metal library from: %@", libraryPath);
            
            if (libraryPath) {
                NSURL *libraryURL = [NSURL fileURLWithPath:libraryPath];
                library = [device newLibraryWithURL:libraryURL error:&error];
                if (!library) {
                    NSLog(@"Failed to load Metal library from URL: %@", error);
                }
            } else {
                NSLog(@"Could not find default.metallib in main bundle");
            }
            
            // If that fails, try loading from source code (useful for tests)
            if (!library) {
                NSLog(@"Attempting to load Metal library from source...");
                // Look in current directory first
                NSString* sourcePath = @"Shaders.metal";
                NSError* readError = nil;
                NSString* source = [NSString stringWithContentsOfFile:sourcePath 
                                                           encoding:NSUTF8StringEncoding 
                                                              error:&readError];
                
                if (!source) {
                    // Then try bundle
                    sourcePath = [[NSBundle mainBundle] pathForResource:@"Shaders" ofType:@"metal"];
                    if (sourcePath) {
                        source = [NSString stringWithContentsOfFile:sourcePath 
                                                         encoding:NSUTF8StringEncoding 
                                                            error:&readError];
                    }
                }
                
                if (source) {
                    NSLog(@"Successfully loaded shader source from %@, compiling...", sourcePath);
                    MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
                    if (@available(macOS 12.0, *)) {
                        options.languageVersion = MTLLanguageVersion2_4;
                    }
                    library = [device newLibraryWithSource:source 
                                                 options:options 
                                                   error:&error];
                    if (!library) {
                        NSLog(@"Failed to compile shader source: %@", error);
                    }
                } else {
                    NSLog(@"Failed to read shader source: %@", readError);
                }
                
                // If still no library, try creating a default one
                if (!library) {
                    NSLog(@"Attempting to load default library...");
                    library = [device newDefaultLibrary];
                    if (!library) {
                        NSLog(@"Failed to load default library");
                    }
                }
            }
            
            if (!library) {
                NSLog(@"All attempts to load Metal library failed: %@", error);
                throw std::runtime_error("Failed to load Metal library");
            }
            
            NSLog(@"Successfully loaded Metal library");
            
            // Get function references
            compressFunction = [library newFunctionWithName:@"compress"];
            decompressFunction = [library newFunctionWithName:@"decompress"];
            if (!compressFunction || !decompressFunction) {
                NSLog(@"Failed to load Metal functions. compress: %@, decompress: %@", 
                      compressFunction ? @"OK" : @"Failed",
                      decompressFunction ? @"OK" : @"Failed");
                throw std::runtime_error("Failed to load Metal functions");
            }
            
            NSLog(@"Successfully loaded Metal functions");
            
            // Create command queue
            commandQueue = [device newCommandQueue];
            if (!commandQueue) {
                NSLog(@"Failed to create command queue");
                throw std::runtime_error("Failed to create command queue");
            }
            
            NSLog(@"Successfully initialized Metal device: %@", [device name]);
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
            NSError* error = nil;
            id<MTLComputePipelineState> pipelineState = [device newComputePipelineStateWithFunction:decompressFunction
                                                                                             error:&error];
            [computeEncoder setComputePipelineState:pipelineState];
            
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
};
