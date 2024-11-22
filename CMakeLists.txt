cmake_minimum_required(VERSION 3.10)
project(FlashCompress CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

# Find GTest package
find_package(GTest REQUIRED)

# Add Homebrew's include and lib directories
include_directories(/opt/homebrew/include)
link_directories(/opt/homebrew/lib)

# Set compiler flags for Objective-C++
set(CMAKE_OBJCXX_FLAGS "${CMAKE_OBJCXX_FLAGS} -x objective-c++ -std=gnu++17")

# Compile Metal shader to metallib
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/default.metallib
    COMMAND xcrun -sdk macosx metal -c ${CMAKE_SOURCE_DIR}/src/Shaders.metal -o ${CMAKE_BINARY_DIR}/Shaders.air
    COMMAND xcrun -sdk macosx metallib ${CMAKE_BINARY_DIR}/Shaders.air -o ${CMAKE_BINARY_DIR}/default.metallib
    DEPENDS ${CMAKE_SOURCE_DIR}/src/Shaders.metal
    COMMENT "Compiling Metal shader"
    VERBATIM
)

# Add the metallib as a dependency
add_custom_target(shaders DEPENDS ${CMAKE_BINARY_DIR}/default.metallib)

# Main executable
add_executable(flashcompress
    src/main.mm
    src/CompressionEngine.mm
)

# Link Metal framework and other dependencies
target_link_libraries(flashcompress PRIVATE
    "-framework Metal"
    "-framework Foundation"
    "-framework QuartzCore"
)

add_dependencies(flashcompress shaders)

# Enable testing
enable_testing()

# Test executables
add_executable(compression_tests
    tests/compression_tests.mm
    src/CompressionEngine.mm
)

add_executable(metal_test
    tests/metal_test.mm
    src/CompressionEngine.mm
)

# Link test dependencies
target_link_libraries(compression_tests PRIVATE
    GTest::GTest
    GTest::Main
    "-framework Metal"
    "-framework Foundation"
    "-framework QuartzCore"
)

target_link_libraries(metal_test PRIVATE
    GTest::GTest
    GTest::Main
    "-framework Metal"
    "-framework Foundation"
    "-framework QuartzCore"
)

# Add dependencies on shaders
add_dependencies(compression_tests shaders)
add_dependencies(metal_test shaders)

# Set RPATH for test executables
set_target_properties(compression_tests metal_test PROPERTIES
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH "$ORIGIN"
)

# Add tests
add_test(NAME metal_test COMMAND metal_test)
add_test(NAME compression_tests COMMAND compression_tests)
