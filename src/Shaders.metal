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
    if (id > *input_size - MIN_MATCH_LENGTH) return;
    
    uint32_t cur_hash = hash_function(input, id);
    uint32_t start = id > WINDOW_SIZE ? id - WINDOW_SIZE : 0;
    
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
            
            if (len > match_lengths[id]) {
                match_lengths[id] = len;
                match_positions[id] = pos;
            }
        }
    }
    
    // Write compressed data
    if (match_lengths[id] >= MIN_MATCH_LENGTH) {
        // Write match information (length and position)
        atomic_store_explicit((device atomic_uint*)(output + id * 8), match_lengths[id], memory_order_relaxed);
        atomic_store_explicit((device atomic_uint*)(output + id * 8 + 4), match_positions[id], memory_order_relaxed);
    } else {
        // Write literal byte
        output[id] = input[id];
    }
}

// Decompression kernel
kernel void decompress(const device uint8_t* input [[buffer(0)]],
                      device uint8_t* output [[buffer(1)]],
                      device uint32_t* output_size [[buffer(2)]],
                      device uint32_t* input_size [[buffer(3)]],
                      uint id [[thread_position_in_grid]]) {
    if (id >= *input_size) return;
    
    uint32_t match_length = *(const device uint32_t*)(input + id * 8);
    uint32_t match_position = *(const device uint32_t*)(input + id * 8 + 4);
    
    if (match_length >= MIN_MATCH_LENGTH) {
        // Copy matched sequence
        for (uint32_t i = 0; i < match_length; ++i) {
            output[id + i] = output[match_position + i];
        }
        atomic_fetch_max_explicit((device atomic_uint*)output_size, id + match_length, memory_order_relaxed);
    } else {
        // Copy literal byte
        output[id] = input[id];
        atomic_fetch_max_explicit((device atomic_uint*)output_size, id + 1, memory_order_relaxed);
    }
}
