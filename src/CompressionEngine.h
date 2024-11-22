#pragma once

#include <vector>
#include <Metal/Metal.h>

class CompressionEngine {
public:
    CompressionEngine();
    ~CompressionEngine();
    
    std::vector<uint8_t> compress(const std::vector<uint8_t>& data);
    std::vector<uint8_t> decompress(const std::vector<uint8_t>& compressedData);
    
private:
    id<MTLDevice> device;
    id<MTLLibrary> library;
    id<MTLFunction> compressFunction;
    id<MTLFunction> decompressFunction;
    id<MTLComputePipelineState> compressPipeline;
    id<MTLComputePipelineState> decompressPipeline;
    id<MTLCommandQueue> commandQueue;
};
