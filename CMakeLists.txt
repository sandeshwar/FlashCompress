cmake_minimum_required(VERSION 3.15)
project(GPUZip CUDA CXX)

set(CMAKE_CUDA_STANDARD 14)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CUDA_ARCHITECTURES 75)

# Find CUDA
find_package(CUDA REQUIRED)
include_directories(${CUDA_INCLUDE_DIRS})

# Add source files
add_executable(gpuzip
    src/main.cu
    src/compression.cu
    src/decompression.cu
    src/gpu_utils.cu
)

# Set CUDA specific flags
set_target_properties(gpuzip PROPERTIES
    CUDA_SEPARABLE_COMPILATION ON
)

target_compile_options(gpuzip PRIVATE $<$<COMPILE_LANGUAGE:CUDA>:
    -O3
    --use_fast_math
    -Xptxas -O3
>)
