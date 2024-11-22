#import <Foundation/Foundation.h>
#include "/opt/homebrew/include/gtest/gtest.h"
#include <Metal/Metal.h>


class MetalTest : public ::testing::Test {
protected:
    id<MTLDevice> device;
    
    void SetUp() override {
        device = MTLCreateSystemDefaultDevice();
        ASSERT_NE(device, nullptr) << "Failed to create Metal device";
        [device retain];
    }
    
    void TearDown() override {
        [device release];
    }
};

TEST_F(MetalTest, DeviceCapabilities) {
    EXPECT_TRUE([device supportsFeatureSet:MTLFeatureSet_macOS_GPUFamily1_v1]);
    EXPECT_GT([device maxThreadgroupMemoryLength], 0);
    EXPECT_GT([device maxThreadsPerThreadgroup].width, 0);
}

TEST_F(MetalTest, CommandQueue) {
    id<MTLCommandQueue> queue = [device newCommandQueue];
    ASSERT_NE(queue, nullptr) << "Failed to create command queue";
    [queue release];
}

TEST_F(MetalTest, Buffer) {
    const size_t bufferSize = 1024;
    id<MTLBuffer> buffer = [device newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    ASSERT_NE(buffer, nullptr) << "Failed to create buffer";
    EXPECT_EQ([buffer length], bufferSize);
    [buffer release];
}

// int main(int argc, char **argv) {
//     testing::InitGoogleTest(&argc, argv);
//     return RUN_ALL_TESTS();
// }
