#include <metal_stdlib>
using namespace metal;

// Constants
constant int MIN_MATCH_LENGTH = 3;
constant int MAX_MATCH_LENGTH = 258;
constant int WINDOW_SIZE = 32768;

// Hash function for string matching
uint32_t hash_function(const device uint8_t* data, uint32_t pos) {
    uint32_t hash = 2166136261u;
    for (uint32_t i = 0; i < MIN_MATCH_LENGTH; ++i) {
        hash ^= data[pos + i];
        hash *= 16777619u;
    }
    return hash;
}

// Compare sequences
bool compare_sequences(const device uint8_t* a, const device uint8_t* b, uint32_t len) {
    for (uint32_t i = 0; i < len; ++i) {
        if (a[i] != b[i]) return false;
    }
    return true;
}

// Compression kernel
kernel void compress(const device uint8_t* input [[buffer(0)]],
                    device uint8_t* output [[buffer(1)]],
                    device uint32_t* match_lengths [[buffer(2)]],
                    device uint32_t* match_positions [[buffer(3)]],
                    device uint32_t* output_size [[buffer(4)]],
                    device uint32_t* input_size [[buffer(5)]],
                    uint id [[thread_position_in_grid]]) {
    if (id >= *input_size) return;
    
    // Initialize with no match
    match_lengths[id] = 0;
    match_positions[id] = 0;
    
    // Don't look for matches near the end
    if (id > *input_size - MIN_MATCH_LENGTH) {
        // Write literal byte
        uint32_t output_pos = atomic_fetch_add_explicit((device atomic_uint*)output_size, 2, memory_order_relaxed);
        output[output_pos] = 0x00; // Flag byte: 0xxxxxxx for literal
        output[output_pos + 1] = input[id];
        return;
    }
    
    uint32_t cur_hash = hash_function(input, id);
    uint32_t start = id > WINDOW_SIZE ? id - WINDOW_SIZE : 0;
    uint32_t best_match_length = 0;
    uint32_t best_match_pos = 0;
    
    // Search for matches in the sliding window
    for (uint32_t pos = start; pos < id; pos++) {
        if (pos + MIN_MATCH_LENGTH > *input_size) break;
        
        uint32_t pos_hash = hash_function(input, pos);
        if (pos_hash == cur_hash && compare_sequences(input + id, input + pos, MIN_MATCH_LENGTH)) {
            // Found a potential match, try to extend it
            uint32_t len = MIN_MATCH_LENGTH;
            while (id + len < *input_size && pos + len < *input_size &&
                   input[id + len] == input[pos + len] && len < MAX_MATCH_LENGTH) {
                len++;
            }
            
            if (len > best_match_length) {
                best_match_length = len;
                best_match_pos = pos;
            }
        }
    }
    
    // Write compressed data
    if (best_match_length >= MIN_MATCH_LENGTH) {
        // Format: [flag byte][length (2 bytes)][position (3 bytes)]
        uint32_t output_pos = atomic_fetch_add_explicit((device atomic_uint*)output_size, 6, memory_order_relaxed);
        output[output_pos] = 0x80; // Flag byte: 1xxxxxxx for match
        output[output_pos + 1] = (best_match_length >> 8) & 0xFF;
        output[output_pos + 2] = best_match_length & 0xFF;
        output[output_pos + 3] = (best_match_pos >> 16) & 0xFF;
        output[output_pos + 4] = (best_match_pos >> 8) & 0xFF;
        output[output_pos + 5] = best_match_pos & 0xFF;
    } else {
        // Write literal byte with flag
        uint32_t output_pos = atomic_fetch_add_explicit((device atomic_uint*)output_size, 2, memory_order_relaxed);
        output[output_pos] = 0x00; // Flag byte: 0xxxxxxx for literal
        output[output_pos + 1] = input[id];
    }
}

// Decompression kernel
kernel void decompress(const device uint8_t* input [[buffer(0)]],
                      device uint8_t* output [[buffer(1)]],
                      device uint32_t* output_size [[buffer(2)]],
                      device uint32_t* input_size [[buffer(3)]],
                      uint id [[thread_position_in_grid]]) {
    if (id >= *input_size) return;
    
    uint32_t pos = 0;
    while (pos < *input_size) {
        uint8_t flag = input[pos];
        if (flag & 0x80) {  // Match
            uint32_t length = (input[pos + 1] << 8) | input[pos + 2];
            uint32_t match_pos = (input[pos + 3] << 16) | (input[pos + 4] << 8) | input[pos + 5];
            
            // Copy matched sequence
            for (uint32_t i = 0; i < length; ++i) {
                uint32_t out_pos = atomic_fetch_add_explicit((device atomic_uint*)output_size, 1, memory_order_relaxed);
                output[out_pos] = output[match_pos + i];
            }
            pos += 6;
        } else {  // Literal
            uint32_t out_pos = atomic_fetch_add_explicit((device atomic_uint*)output_size, 1, memory_order_relaxed);
            output[out_pos] = input[pos + 1];
            pos += 2;
        }
    }
}
