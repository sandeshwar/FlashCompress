cmake_minimum_required(VERSION 3.15)
project(GPUZip CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(GTest REQUIRED)

# Main executable
add_executable(gpuzip
    src/main.mm
    src/CompressionEngine.mm
)

# Link Metal framework and other dependencies
target_link_libraries(gpuzip
    "-framework Metal"
    "-framework Foundation"
)

# Test executable
add_executable(compression_tests
    tests/compression_tests.mm
    src/CompressionEngine.mm
)

# Link test dependencies
target_link_libraries(compression_tests
    GTest::GTest
    GTest::Main
    "-framework Metal"
    "-framework Foundation"
)

# Enable testing
enable_testing()
add_test(NAME compression_tests COMMAND compression_tests)

# Copy Metal shader file to build directory
configure_file(${CMAKE_SOURCE_DIR}/src/Shaders.metal
               ${CMAKE_BINARY_DIR}/Shaders.metal COPYONLY)
