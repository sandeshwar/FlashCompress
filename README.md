# GPUZip - High Performance GPU-based Compression

A cutting-edge lossless compression program that utilizes GPU acceleration to achieve superior compression speeds.

## Requirements
- CUDA Toolkit 11.0 or higher
- C++17 compatible compiler
- CMake 3.15 or higher
- Thrust library (included with CUDA)

## Building
```bash
mkdir build
cd build
cmake ..
make
```

## Usage
```bash
# Compression
./gpuzip compress input_file output_file

# Decompression
./gpuzip decompress input_file output_file
```

## Algorithm
The compression algorithm uses a hybrid approach:
1. Parallel dictionary coding optimized for GPU
2. Entropy encoding with adaptive modeling
3. Block-based compression for optimal GPU utilization
4. Parallel prefix sum for efficient symbol mapping

## Performance
Target: 5x faster than current state-of-the-art compression tools while maintaining comparable compression ratios.
