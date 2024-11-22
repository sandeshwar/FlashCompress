#include "gpuzip.cuh"
#include <cuda_runtime.h>
#include <iostream>

// GPU Memory Management Helper Functions
class GPUMemoryManager {
public:
    static bool allocateMemory(void** ptr, size_t size) {
        cudaError_t status = cudaMalloc(ptr, size);
        if (status != cudaSuccess) {
            std::cerr << "Failed to allocate GPU memory: " 
                      << cudaGetErrorString(status) << std::endl;
            return false;
        }
        return true;
    }

    static bool copyToDevice(void* dst, const void* src, size_t size) {
        cudaError_t status = cudaMemcpy(dst, src, size, cudaMemcpyHostToDevice);
        if (status != cudaSuccess) {
            std::cerr << "Failed to copy data to GPU: " 
                      << cudaGetErrorString(status) << std::endl;
            return false;
        }
        return true;
    }

    static bool copyToHost(void* dst, const void* src, size_t size) {
        cudaError_t status = cudaMemcpy(dst, src, size, cudaMemcpyDeviceToHost);
        if (status != cudaSuccess) {
            std::cerr << "Failed to copy data from GPU: " 
                      << cudaGetErrorString(status) << std::endl;
            return false;
        }
        return true;
    }

    static void freeMemory(void* ptr) {
        if (ptr != nullptr) {
            cudaFree(ptr);
        }
    }
};

// CUDA Error Checking Helper
class CUDAErrorChecker {
public:
    static bool checkLastError(const char* errorMessage) {
        cudaError_t status = cudaGetLastError();
        if (status != cudaSuccess) {
            std::cerr << errorMessage << ": " 
                      << cudaGetErrorString(status) << std::endl;
            return false;
        }
        return true;
    }

    static bool checkKernelExecution(const char* kernelName) {
        cudaError_t status = cudaDeviceSynchronize();
        if (status != cudaSuccess) {
            std::cerr << "Kernel execution failed (" << kernelName << "): " 
                      << cudaGetErrorString(status) << std::endl;
            return false;
        }
        return true;
    }
};

// GPU Device Properties Helper
class GPUDeviceProperties {
public:
    static bool getOptimalBlockSize(int* blockSize) {
        cudaDeviceProp prop;
        cudaError_t status = cudaGetDeviceProperties(&prop, 0);
        if (status != cudaSuccess) {
            std::cerr << "Failed to get device properties: " 
                      << cudaGetErrorString(status) << std::endl;
            return false;
        }
        
        *blockSize = prop.maxThreadsPerBlock;
        return true;
    }

    static bool getDeviceMemory(size_t* totalMem, size_t* freeMem) {
        cudaError_t status = cudaMemGetInfo(freeMem, totalMem);
        if (status != cudaSuccess) {
            std::cerr << "Failed to get device memory info: " 
                      << cudaGetErrorString(status) << std::endl;
            return false;
        }
        return true;
    }
};
