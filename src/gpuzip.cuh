#pragma once

#include <cuda_runtime.h>
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#include <cstdint>

// Constants for compression
constexpr size_t BLOCK_SIZE = 1024;
constexpr size_t DICTIONARY_SIZE = 1 << 16;
constexpr size_t MIN_MATCH_LENGTH = 3;
constexpr size_t MAX_MATCH_LENGTH = 258;

// Structure for compression parameters
struct CompressionParams {
    uint32_t block_size;
    uint32_t dictionary_size;
    float compression_level;
};

// CUDA kernel declarations
namespace gpuzip {
    // Compression functions
    __global__ void findMatches(const uint8_t* input, size_t input_size,
                              uint32_t* match_lengths, uint32_t* match_positions);
    
    __global__ void compressBlock(const uint8_t* input, size_t input_size,
                                const uint32_t* match_lengths,
                                const uint32_t* match_positions,
                                uint8_t* output, size_t* output_size);

    // Decompression functions
    __global__ void decompressBlock(const uint8_t* input, size_t input_size,
                                  uint8_t* output, size_t* output_size);

    // Utility functions
    __device__ uint32_t hash(const uint8_t* data, size_t size);
    __device__ bool compareSequences(const uint8_t* a, const uint8_t* b, size_t max_len);
}

// Host interface functions
bool compressFile(const char* input_path, const char* output_path, const CompressionParams& params);
bool decompressFile(const char* input_path, const char* output_path);
