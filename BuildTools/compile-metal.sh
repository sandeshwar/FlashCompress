#!/bin/bash
set -e  # Exit on any error

# Set paths
METAL_SOURCE="Sources/FlashCompress/Metal/Kernels.metal"
OUTPUT_DIR="Sources/FlashCompress/Resources/Metal"
TEMP_AIR="temp.air"

# Check if Metal source exists
if [ ! -f "$METAL_SOURCE" ]; then
    echo "Error: Metal source file not found at $METAL_SOURCE"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Metal source file: $METAL_SOURCE"
echo "Output directory: $OUTPUT_DIR"
echo "Temporary air file: $TEMP_AIR"

echo "Compiling Metal shader with verbose output..."

# Compile Metal shader to intermediate .air file with verbose output
if ! xcrun -sdk macosx metal -v -c "$METAL_SOURCE" -o "$TEMP_AIR"; then
    echo "Error: Failed to compile Metal shader"
    exit 1
fi

echo "Verifying .air file..."
if [ ! -f "$TEMP_AIR" ]; then
    echo "Error: .air file was not created"
    exit 1
fi

echo "Creating metallib with verbose output..."

# Create metallib from .air file with verbose output
if ! xcrun -sdk macosx metallib -v "$TEMP_AIR" -o "$OUTPUT_DIR/default.metallib"; then
    echo "Error: Failed to create metallib"
    rm -f "$TEMP_AIR"
    exit 1
fi

echo "Verifying metallib file..."
if [ ! -f "$OUTPUT_DIR/default.metallib" ]; then
    echo "Error: metallib file was not created"
    rm -f "$TEMP_AIR"
    exit 1
fi

# Get file info
echo "Metallib file info:"
ls -l "$OUTPUT_DIR/default.metallib"

# Clean up temporary file
rm -f "$TEMP_AIR"

echo "Metal compilation successful!"
echo "Output: $OUTPUT_DIR/default.metallib"