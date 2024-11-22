# GPUZip - High Performance GPU-based Compression

A cutting-edge lossless compression program that utilizes GPU acceleration through Metal framework to achieve superior compression speeds on macOS platforms.

## Features
- GPU-accelerated compression using Metal framework
- Sliding window compression algorithm with parallel processing
- Automatic Reference Counting (ARC) support
- Efficient memory management
- Command-line interface for compression and decompression

## Requirements
- macOS 14.0 or higher
- Apple Silicon (M1/M2) or Intel Mac with Metal support
- Xcode 15.0 or higher

## Building
```bash
# Open the project in Xcode
open GPUZip.xcodeproj

# Build using xcodebuild
xcodebuild -project GPUZip.xcodeproj -scheme gpuzip -configuration Release
```

## Usage
```bash
# Compression
./gpuzip compress input_file output_file

# Decompression
./gpuzip decompress input_file output_file
```

## Algorithm
The compression algorithm implements:
1. Parallel sliding window compression optimized for Metal
2. Hash-based string matching for efficient pattern detection
3. Thread group optimization (256 threads per group)
4. Atomic operations for concurrent memory access
5. Conservative output size estimation

## Technical Details
- Language: Objective-C++ with Metal shaders
- Build System: Xcode
- Minimum Deployment Target: macOS 14.0
- Architecture Support: arm64 (Apple Silicon)
- Memory Management: ARC (Automatic Reference Counting)

## Implementation
The project consists of several key components:
1. `CompressionEngine`: Core class handling compression operations
2. `Metal Shaders`: GPU kernels for compression and decompression
3. `Command-line Interface`: User interface for file operations

### Metal Shader Features
- Configurable sliding window size (32KB)
- Minimum match length of 3 bytes
- Maximum match length of 258 bytes
- FNV-1a hash function for string matching
- Atomic operations for thread-safe output

## Performance Considerations
- Optimized for Apple Silicon processors
- Efficient memory bandwidth utilization
- Parallel processing of compression blocks
- Thread group size optimization
- Memory coalescing for better throughput

## Current Status
This is an experimental implementation focusing on:
- Metal framework integration
- Basic sliding window compression
- Memory safety through ARC
- Cross-architecture compatibility

## Future Improvements
1. Enhanced compression algorithms
2. Comprehensive error handling
3. Performance benchmarking
4. Extended test coverage
5. Memory usage optimization
6. Multi-GPU support

## License
[Add your license information here]
