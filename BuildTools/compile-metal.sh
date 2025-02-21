#!/bin/bash

# Set paths
METAL_SOURCE="Sources/FlashCompress/Metal/Kernels.metal"
OUTPUT_DIR="Sources/FlashCompress/Resources/Metal"
TEMP_AIR="temp.air"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Compile Metal shader to intermediate .air file
xcrun -sdk macosx metal -c "$METAL_SOURCE" -o "$TEMP_AIR"

# Create metallib from .air file
xcrun -sdk macosx metallib "$TEMP_AIR" -o "$OUTPUT_DIR/default.metallib"

# Clean up temporary file
rm "$TEMP_AIR"