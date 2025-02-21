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

echo "Compiling Metal shader..."

# Compile Metal shader to intermediate .air file
if ! xcrun -sdk macosx metal -c "$METAL_SOURCE" -o "$TEMP_AIR"; then
    echo "Error: Failed to compile Metal shader"
    exit 1
fi

echo "Creating metallib..."

# Create metallib from .air file
if ! xcrun -sdk macosx metallib "$TEMP_AIR" -o "$OUTPUT_DIR/default.metallib"; then
    echo "Error: Failed to create metallib"
    rm -f "$TEMP_AIR"
    exit 1
fi

# Clean up temporary file
rm -f "$TEMP_AIR"

echo "Metal compilation successful!"
echo "Output: $OUTPUT_DIR/default.metallib"