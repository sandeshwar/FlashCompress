#include "gpuzip.cuh"
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#include <thrust/execution_policy.h>
#include <thrust/scan.h>
#include <cstring>

namespace gpuzip {

__device__ uint32_t hash(const uint8_t* data, size_t size) {
    uint32_t hash = 2166136261u;
    for (size_t i = 0; i < size; ++i) {
        hash ^= data[i];
        hash *= 16777619u;
    }
    return hash;
}

__device__ bool compareSequences(const uint8_t* a, const uint8_t* b, size_t max_len) {
    for (size_t i = 0; i < max_len; ++i) {
        if (a[i] != b[i]) return false;
    }
    return true;
}

__global__ void findMatches(const uint8_t* input, size_t input_size,
                          uint32_t* match_lengths, uint32_t* match_positions) {
    const int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= input_size) return;

    // Initialize with no match
    match_lengths[idx] = 0;
    match_positions[idx] = 0;

    // Don't look for matches near the end of the input
    if (idx > input_size - MIN_MATCH_LENGTH) return;

    // Compute hash of current position
    uint32_t cur_hash = hash(input + idx, MIN_MATCH_LENGTH);
    
    // Search for matches in the sliding window
    const int window_size = 32768; // 32KB sliding window
    const int start = max(0, idx - window_size);
    
    for (int pos = start; pos < idx; pos++) {
        if (pos + MIN_MATCH_LENGTH > input_size) break;
        
        uint32_t pos_hash = hash(input + pos, MIN_MATCH_LENGTH);
        if (pos_hash == cur_hash && compareSequences(input + idx, input + pos, MIN_MATCH_LENGTH)) {
            // Found a potential match, try to extend it
            size_t len = MIN_MATCH_LENGTH;
            while (idx + len < input_size && pos + len < input_size &&
                   input[idx + len] == input[pos + len] && len < MAX_MATCH_LENGTH) {
                len++;
            }
            
            if (len > match_lengths[idx]) {
                match_lengths[idx] = len;
                match_positions[idx] = pos;
            }
        }
    }
}

__global__ void compressBlock(const uint8_t* input, size_t input_size,
                            const uint32_t* match_lengths,
                            const uint32_t* match_positions,
                            uint8_t* output, size_t* output_size) {
    const int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= input_size) return;

    // Simple byte-by-byte compression for now
    // TODO: Implement advanced entropy coding
    if (match_lengths[idx] >= MIN_MATCH_LENGTH) {
        // Write match information
        uint32_t match_info = (match_lengths[idx] << 24) | match_positions[idx];
        memcpy(output + idx * sizeof(uint32_t), &match_info, sizeof(uint32_t));
    } else {
        // Write literal byte
        output[idx] = input[idx];
    }
}

} // namespace gpuzip

bool compressFile(const char* input_path, const char* output_path, const CompressionParams& params) {
    // Read input file
    std::vector<uint8_t> input_data;
    if (!readFile(input_path, input_data)) {
        return false;
    }

    size_t input_size = input_data.size();
    
    // Allocate device memory
    thrust::device_vector<uint8_t> d_input(input_data);
    thrust::device_vector<uint32_t> d_match_lengths(input_size);
    thrust::device_vector<uint32_t> d_match_positions(input_size);
    thrust::device_vector<uint8_t> d_output(input_size * 2); // Worst case size
    
    // Calculate grid dimensions
    const int block_size = 256;
    const int num_blocks = (input_size + block_size - 1) / block_size;
    
    // Find matches
    gpuzip::findMatches<<<num_blocks, block_size>>>(
        thrust::raw_pointer_cast(d_input.data()),
        input_size,
        thrust::raw_pointer_cast(d_match_lengths.data()),
        thrust::raw_pointer_cast(d_match_positions.data())
    );
    
    // Check for kernel errors
    cudaError_t cuda_status = cudaGetLastError();
    if (cuda_status != cudaSuccess) {
        std::cerr << "Kernel error: " << cudaGetErrorString(cuda_status) << "\n";
        return false;
    }
    
    // Compress data
    size_t* d_output_size;
    cudaMalloc(&d_output_size, sizeof(size_t));
    cudaMemset(d_output_size, 0, sizeof(size_t));
    
    gpuzip::compressBlock<<<num_blocks, block_size>>>(
        thrust::raw_pointer_cast(d_input.data()),
        input_size,
        thrust::raw_pointer_cast(d_match_lengths.data()),
        thrust::raw_pointer_cast(d_match_positions.data()),
        thrust::raw_pointer_cast(d_output.data()),
        d_output_size
    );
    
    // Get compressed size
    size_t output_size;
    cudaMemcpy(&output_size, d_output_size, sizeof(size_t), cudaMemcpyDeviceToHost);
    cudaFree(d_output_size);
    
    // Copy compressed data back to host
    std::vector<uint8_t> output_data(output_size);
    thrust::copy(d_output.begin(), d_output.begin() + output_size, output_data.begin());
    
    // Write output file
    return writeFile(output_path, output_data);
}
