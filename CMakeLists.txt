cmake_minimum_required(VERSION 3.10)
project(GPUZip)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add Homebrew's include and lib directories
include_directories(/opt/homebrew/include)
link_directories(/opt/homebrew/lib)

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
    gtest
    gtest_main
    pthread
    "-framework Metal"
    "-framework Foundation"
)

# Set RPATH for the test executable
set_target_properties(compression_tests PROPERTIES
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH "$ORIGIN"
)

# Metal test executable
add_executable(metal_test
    tests/metal_test.mm
)

target_link_libraries(metal_test
    "-framework Metal"
    "-framework Foundation"
)

# Enable testing
enable_testing()
add_test(NAME compression_tests COMMAND compression_tests)

# Copy Metal shader file to build directory
configure_file(${CMAKE_SOURCE_DIR}/src/Shaders.metal
               ${CMAKE_BINARY_DIR}/Shaders.metal COPYONLY)
