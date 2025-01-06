#include <metal_stdlib>
using namespace metal;

struct CompressionParams {
    uint32_t inputLength;
    uint32_t dictionarySize;
    uint32_t windowSize;
    uint32_t minMatchLength;
    uint32_t maxMatchLength;
};

// Structure to hold LZ77 match information
struct Match {
    uint32_t distance;
    uint32_t length;
    uint32_t literal;
    bool isMatch;
};

// Helper function to find the longest match
static Match find_longest_match(
    const device uint8_t* input,
    uint32_t pos,
    uint32_t inputLength,
    uint32_t windowSize,
    uint32_t minMatchLength,
    uint32_t maxMatchLength
) {
    Match bestMatch = { 0, 0, input[pos], false };
    
    if (pos >= inputLength - minMatchLength) {
        return bestMatch;
    }
    
    // Calculate window boundaries
    uint32_t windowStart = (pos > windowSize) ? (pos - windowSize) : 0;
    uint32_t maxMatchEnd = min(pos + maxMatchLength, inputLength);
    
    // Search through the sliding window
    for (uint32_t i = windowStart; i < pos; i++) {
        uint32_t matchLength = 0;
        uint32_t currentPos = i;
        uint32_t lookAheadPos = pos;
        
        // Compare bytes
        while (lookAheadPos < maxMatchEnd && 
               currentPos < pos + (maxMatchEnd - pos) &&
               input[currentPos] == input[lookAheadPos] && 
               matchLength < maxMatchLength) {
            matchLength++;
            currentPos++;
            lookAheadPos++;
        }
        
        // Update best match if this one is longer and meets minimum length
        if (matchLength >= minMatchLength && matchLength > bestMatch.length) {
            bestMatch.distance = pos - i;
            bestMatch.length = matchLength;
            bestMatch.isMatch = true;
        }
    }
    
    return bestMatch;
}

// Main compression kernel
kernel void compressBlock(
    const device uint8_t* input [[buffer(0)]],
    device uint8_t* output [[buffer(1)]],
    device CompressionParams& params [[buffer(2)]],
    device atomic_uint* outputSize [[buffer(3)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= params.inputLength) return;
    
    // Find the longest match at this position
    Match match = find_longest_match(
        input,
        index,
        params.inputLength,
        params.windowSize,
        params.minMatchLength,
        params.maxMatchLength
    );
    
    // Calculate output position atomically
    uint32_t outputPos = atomic_fetch_add_explicit(
        outputSize,
        match.isMatch ? 8 : 1,  // 8 bytes for match, 1 for literal
        memory_order_relaxed
    );
    
    // Write match or literal
    if (match.isMatch) {
        // Format: [1-bit flag][15-bit length][16-bit distance]
        uint32_t encoded = (1u << 31) | ((match.length & 0x7FFF) << 16) | (match.distance & 0xFFFF);
        device uint32_t* out32 = reinterpret_cast<device uint32_t*>(&output[outputPos]);
        *out32 = encoded;
    } else {
        output[outputPos] = match.literal;
    }
}
