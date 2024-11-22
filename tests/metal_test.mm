#import <Foundation/Foundation.h>
#include "/opt/homebrew/include/gtest/gtest.h"
#include <Metal/Metal.h>
#include "../src/CompressionEngine.h"

class MetalTest : public ::testing::Test {
protected:
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    
    void SetUp() override {
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
            
            ASSERT_NE(device, nullptr) << "Failed to create Metal device";
            [device retain];
            
            commandQueue = [device newCommandQueue];
            ASSERT_NE(commandQueue, nullptr) << "Failed to create command queue";
        }
    }
    
    void TearDown() override {
        @autoreleasepool {
            if (commandQueue) {
                [commandQueue release];
            }
            if (device) {
                [device release];
            }
        }
    }
};

TEST_F(MetalTest, DeviceCapabilities) {
    @autoreleasepool {
        EXPECT_TRUE([device supportsFeatureSet:MTLFeatureSet_macOS_GPUFamily1_v1]);
        EXPECT_GT([device maxThreadgroupMemoryLength], 0);
        EXPECT_GT([device maxThreadsPerThreadgroup].width, 0);
        
        std::cout << "Device capabilities:\n"
                  << "  Max threadgroup memory: " << [device maxThreadgroupMemoryLength] << " bytes\n"
                  << "  Max threads per threadgroup: " << [device maxThreadsPerThreadgroup].width << "\n"
                  << "  Max buffer length: " << [device maxBufferLength] << " bytes\n";
    }
}

TEST_F(MetalTest, CommandQueue) {
    @autoreleasepool {
        id<MTLCommandQueue> queue = [device newCommandQueue];
        ASSERT_NE(queue, nullptr) << "Failed to create command queue";
        [queue release];
    }
}

TEST_F(MetalTest, Buffer) {
    @autoreleasepool {
        const size_t bufferSize = 1024;
        id<MTLBuffer> buffer = [device newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
        ASSERT_NE(buffer, nullptr) << "Failed to create buffer";
        EXPECT_EQ([buffer length], bufferSize);
        [buffer release];
    }
}

TEST_F(MetalTest, ShaderLibrary) {
    @autoreleasepool {
        NSError* error = nil;
        NSString* executablePath = [[NSBundle mainBundle] executablePath];
        NSString* executableDir = [executablePath stringByDeletingLastPathComponent];
        NSURL* libraryURL = [NSURL fileURLWithPath:[executableDir stringByAppendingPathComponent:@"default.metallib"]];
        
        std::cout << "Looking for Metal library at: " << [libraryURL.path UTF8String] << "\n";
        
        id<MTLLibrary> library = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:libraryURL.path]) {
            std::cout << "Metal library file exists\n";
            library = [device newLibraryWithURL:libraryURL error:&error];
        } else {
            std::cerr << "Metal library not found at path. Trying default library...\n";
            library = [device newDefaultLibrary];
        }
        
        ASSERT_NE(library, nullptr) << "Failed to load Metal library. Error: " 
                                   << (error ? [[error localizedDescription] UTF8String] : "Unknown error");
        
        // Try to load the compression functions
        id<MTLFunction> compressFunction = [library newFunctionWithName:@"compress"];
        id<MTLFunction> decompressFunction = [library newFunctionWithName:@"decompress"];
        
        ASSERT_NE(compressFunction, nullptr) << "Failed to load compress function";
        ASSERT_NE(decompressFunction, nullptr) << "Failed to load decompress function";
        
        // Create pipeline states
        error = nil;
        id<MTLComputePipelineState> compressPipeline = [device newComputePipelineStateWithFunction:compressFunction error:&error];
        ASSERT_NE(compressPipeline, nullptr) << "Failed to create compress pipeline state. Error: "
                                            << (error ? [[error localizedDescription] UTF8String] : "Unknown error");
        
        error = nil;
        id<MTLComputePipelineState> decompressPipeline = [device newComputePipelineStateWithFunction:decompressFunction error:&error];
        ASSERT_NE(decompressPipeline, nullptr) << "Failed to create decompress pipeline state. Error: "
                                              << (error ? [[error localizedDescription] UTF8String] : "Unknown error");
        
        [compressPipeline release];
        [decompressPipeline release];
        [compressFunction release];
        [decompressFunction release];
        [library release];
    }
}

class CompressionTest : public ::testing::Test {
protected:
    CompressionEngine* engine;
    
    void SetUp() override {
        engine = new CompressionEngine();
        ASSERT_NE(engine, nullptr) << "Failed to create CompressionEngine";
    }
    
    void TearDown() override {
        delete engine;
    }
    
    // Helper function to create test data with repeating patterns
    std::vector<uint8_t> createPatternData(size_t size, size_t pattern_length) {
        std::vector<uint8_t> data(size);
        for (size_t i = 0; i < size; i++) {
            data[i] = static_cast<uint8_t>(i % pattern_length);
        }
        return data;
    }
    
    // Helper function to verify compression format
    void verifyCompressionFormat(const std::vector<uint8_t>& compressed) {
        ASSERT_GT(compressed.size(), 0) << "Compressed data is empty";
        
        for (size_t i = 0; i < compressed.size();) {
            uint8_t flag = compressed[i];
            if ((flag & 0x80) == 0) {  // Literal
                ASSERT_LT(i + 1, compressed.size()) << "Invalid literal at position " << i;
                i += 2;  // Skip flag and literal byte
            } else {  // Match
                ASSERT_LT(i + 5, compressed.size()) << "Invalid match at position " << i;
                uint16_t length = (compressed[i + 1] << 8) | compressed[i + 2];
                uint32_t position = (compressed[i + 3] << 16) | (compressed[i + 4] << 8) | compressed[i + 5];
                EXPECT_GE(length, 3) << "Match length too small at position " << i;
                EXPECT_LE(length, 258) << "Match length too large at position " << i;
                i += 6;  // Skip flag, length (2 bytes), and position (3 bytes)
            }
        }
    }
};

TEST_F(CompressionTest, CompressEmptyInput) {
    std::vector<uint8_t> input;
    std::vector<uint8_t> compressed = engine->compress(input);
    EXPECT_EQ(compressed.size(), 0);
}

TEST_F(CompressionTest, CompressSmallInput) {
    std::vector<uint8_t> input = {1, 2, 3, 4, 5};
    std::vector<uint8_t> compressed = engine->compress(input);
    EXPECT_GT(compressed.size(), 0);
    verifyCompressionFormat(compressed);
}

TEST_F(CompressionTest, CompressRepeatingPattern) {
    // Create data with repeating pattern that should be well-compressed
    std::vector<uint8_t> input = createPatternData(1024, 16);
    std::vector<uint8_t> compressed = engine->compress(input);
    
    EXPECT_GT(compressed.size(), 0);
    EXPECT_LT(compressed.size(), input.size()) << "Compression failed to reduce size";
    verifyCompressionFormat(compressed);
}

TEST_F(CompressionTest, CompressRandomData) {
    // Create pseudo-random data that should be harder to compress
    std::vector<uint8_t> input(1024);
    for (size_t i = 0; i < input.size(); i++) {
        input[i] = static_cast<uint8_t>(rand() & 0xFF);
    }
    
    std::vector<uint8_t> compressed = engine->compress(input);
    EXPECT_GT(compressed.size(), 0);
    verifyCompressionFormat(compressed);
}

TEST_F(CompressionTest, CompressLargeInput) {
    // Test with a larger input to stress test the GPU implementation
    std::vector<uint8_t> input = createPatternData(1024 * 1024, 64);  // 1MB of data
    std::vector<uint8_t> compressed = engine->compress(input);
    
    EXPECT_GT(compressed.size(), 0);
    EXPECT_LT(compressed.size(), input.size()) << "Compression failed to reduce size";
    verifyCompressionFormat(compressed);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        testing::InitGoogleTest(&argc, argv);
        return RUN_ALL_TESTS();
    }
}
