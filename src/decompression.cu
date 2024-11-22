#include "gpuzip.cuh"
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>

namespace gpuzip {

__global__ void decompressBlock(const uint8_t* input, size_t input_size,
                              uint8_t* output, size_t* output_size) {
    const int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= input_size) return;

    // Read compression flag
    uint32_t match_info;
    memcpy(&match_info, input + idx * sizeof(uint32_t), sizeof(uint32_t));
    
    uint32_t match_length = match_info >> 24;
    uint32_t match_position = match_info & 0x00FFFFFF;
    
    if (match_length >= MIN_MATCH_LENGTH) {
        // Copy matched sequence
        for (uint32_t i = 0; i < match_length; ++i) {
            output[idx + i] = output[match_position + i];
        }
        atomicMax(output_size, idx + match_length);
    } else {
        // Copy literal byte
        output[idx] = input[idx];
        atomicMax(output_size, idx + 1);
    }
}

} // namespace gpuzip

bool decompressFile(const char* input_path, const char* output_path) {
    // Read compressed file
    std::vector<uint8_t> input_data;
    if (!readFile(input_path, input_data)) {
        return false;
    }

    size_t input_size = input_data.size();
    
    // Allocate device memory
    thrust::device_vector<uint8_t> d_input(input_data);
    thrust::device_vector<uint8_t> d_output(input_size * 4); // Conservative estimate
    
    // Calculate grid dimensions
    const int block_size = 256;
    const int num_blocks = (input_size + block_size - 1) / block_size;
    
    // Decompress data
    size_t* d_output_size;
    cudaMalloc(&d_output_size, sizeof(size_t));
    cudaMemset(d_output_size, 0, sizeof(size_t));
    
    gpuzip::decompressBlock<<<num_blocks, block_size>>>(
        thrust::raw_pointer_cast(d_input.data()),
        input_size,
        thrust::raw_pointer_cast(d_output.data()),
        d_output_size
    );
    
    // Check for kernel errors
    cudaError_t cuda_status = cudaGetLastError();
    if (cuda_status != cudaSuccess) {
        std::cerr << "Kernel error: " << cudaGetErrorString(cuda_status) << "\n";
        return false;
    }
    
    // Get decompressed size
    size_t output_size;
    cudaMemcpy(&output_size, d_output_size, sizeof(size_t), cudaMemcpyDeviceToHost);
    cudaFree(d_output_size);
    
    // Copy decompressed data back to host
    std::vector<uint8_t> output_data(output_size);
    thrust::copy(d_output.begin(), d_output.begin() + output_size, output_data.begin());
    
    // Write output file
    return writeFile(output_path, output_data);
}
