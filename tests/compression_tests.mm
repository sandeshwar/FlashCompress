#include <gtest/gtest.h>
#include "../src/CompressionEngine.mm"
#include <vector>
#include <random>
#include <algorithm>
#include <dispatch/dispatch.h>
#include <mutex>

class CompressionTest : public ::testing::Test {
protected:
    CompressionEngine engine;
    
    // Helper function to generate random data
    std::vector<uint8_t> generateRandomData(size_t size) {
        std::vector<uint8_t> data(size);
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> dis(0, 255);
        
        for (size_t i = 0; i < size; ++i) {
            data[i] = static_cast<uint8_t>(dis(gen));
        }
        return data;
    }
    
    // Helper function to generate repetitive data
    std::vector<uint8_t> generateRepetitiveData(size_t size) {
        std::vector<uint8_t> data(size);
        const std::string pattern = "HelloWorldThisIsATestPattern";
        
        for (size_t i = 0; i < size; ++i) {
            data[i] = pattern[i % pattern.length()];
        }
        return data;
    }
};

// Test basic compression and decompression
TEST_F(CompressionTest, BasicCompressionDecompression) {
    std::vector<uint8_t> original = {'H', 'e', 'l', 'l', 'o', ' ', 'W', 'o', 'r', 'l', 'd'};
    
    // Compress
    std::vector<uint8_t> compressed = engine.compress(original);
    ASSERT_GT(compressed.size(), 0);
    
    // Decompress
    std::vector<uint8_t> decompressed = engine.decompress(compressed);
    
    // Verify
    ASSERT_EQ(original.size(), decompressed.size());
    EXPECT_EQ(original, decompressed);
}

// Test empty input
TEST_F(CompressionTest, EmptyInput) {
    std::vector<uint8_t> empty;
    
    auto compressed = engine.compress(empty);
    EXPECT_EQ(compressed.size(), 0);
    
    auto decompressed = engine.decompress(compressed);
    EXPECT_EQ(decompressed.size(), 0);
}

// Test large random data
TEST_F(CompressionTest, LargeRandomData) {
    const size_t size = 1024 * 1024; // 1MB
    auto original = generateRandomData(size);
    
    // Compress
    auto compressed = engine.compress(original);
    ASSERT_GT(compressed.size(), 0);
    
    // Decompress
    auto decompressed = engine.decompress(compressed);
    
    // Verify
    ASSERT_EQ(original.size(), decompressed.size());
    EXPECT_EQ(original, decompressed);
}

// Test highly compressible data
TEST_F(CompressionTest, CompressibleData) {
    const size_t size = 1024 * 1024; // 1MB
    auto original = generateRepetitiveData(size);
    
    // Compress
    auto compressed = engine.compress(original);
    ASSERT_GT(compressed.size(), 0);
    EXPECT_LT(compressed.size(), original.size()); // Should achieve compression
    
    // Decompress
    auto decompressed = engine.decompress(compressed);
    
    // Verify
    ASSERT_EQ(original.size(), decompressed.size());
    EXPECT_EQ(original, decompressed);
}

// Test compression speed
TEST_F(CompressionTest, CompressionSpeed) {
    const size_t size = 10 * 1024 * 1024; // 10MB
    auto data = generateRandomData(size);
    
    auto start = std::chrono::high_resolution_clock::now();
    auto compressed = engine.compress(data);
    auto end = std::chrono::high_resolution_clock::now();
    
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    std::cout << "Compression speed: " << (size / 1024.0 / 1024.0) / (duration.count() / 1000.0) << " MB/s\n";
    
    // Verify compression is reasonably fast (at least 100 MB/s)
    EXPECT_LT(duration.count(), (size / (100 * 1024 * 1024)) * 1000);
}

// Test parallel compression
TEST_F(CompressionTest, ParallelCompression) {
    const size_t num_threads = 4;
    const size_t size_per_thread = 1024 * 1024; // 1MB per thread
    std::vector<std::vector<uint8_t>> original_data(num_threads);
    __block std::vector<std::vector<uint8_t>> compressed_data(num_threads);
    
    // Generate data first
    for (size_t i = 0; i < num_threads; ++i) {
        original_data[i] = generateRandomData(size_per_thread);
    }
    
    // Create a concurrent queue for parallel compression
    dispatch_queue_t queue = dispatch_queue_create("com.gpuzip.compression", 
                                                 dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT,
                                                                                       QOS_CLASS_USER_INITIATED, 0));
    dispatch_group_t group = dispatch_group_create();
    
    // Capture 'this' as a non-const pointer
    __block auto* self = this;
    
    // Launch compression tasks
    for (size_t i = 0; i < num_threads; ++i) {
        dispatch_group_async(group, queue, ^{
            compressed_data[i] = std::move(self->engine.compress(original_data[i]));
        });
    }
    
    // Wait for all compressions to complete
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // Cleanup
    dispatch_release(group);
    dispatch_release(queue);
    
    // Verify all compressions succeeded
    ASSERT_EQ(compressed_data.size(), num_threads);
    for (size_t i = 0; i < num_threads; ++i) {
        ASSERT_GT(compressed_data[i].size(), 0);
        auto decompressed = self->engine.decompress(compressed_data[i]);
        EXPECT_EQ(original_data[i], decompressed);
    }
}

// Test compression ratio
TEST_F(CompressionTest, CompressionRatio) {
    const size_t size = 1024 * 1024; // 1MB
    auto repetitive_data = generateRepetitiveData(size);
    auto random_data = generateRandomData(size);
    
    // Test repetitive data
    auto compressed_repetitive = engine.compress(repetitive_data);
    double ratio_repetitive = static_cast<double>(repetitive_data.size()) / compressed_repetitive.size();
    std::cout << "Compression ratio for repetitive data: " << ratio_repetitive << ":1\n";
    EXPECT_GT(ratio_repetitive, 2.0); // Should achieve at least 2:1 compression
    
    // Test random data
    auto compressed_random = engine.compress(random_data);
    double ratio_random = static_cast<double>(random_data.size()) / compressed_random.size();
    std::cout << "Compression ratio for random data: " << ratio_random << ":1\n";
    EXPECT_GT(ratio_random, 0.9); // Should not expand too much
}

// Test error handling
TEST_F(CompressionTest, ErrorHandling) {
    // Test invalid compressed data
    std::vector<uint8_t> invalid_data = {0, 1, 2, 3};
    EXPECT_THROW(engine.decompress(invalid_data), std::runtime_error);
    
    // Test extremely large input
    const size_t huge_size = 1024ULL * 1024ULL * 1024ULL * 2ULL; // 2GB
    EXPECT_THROW({
        std::vector<uint8_t> huge_data(huge_size, 0);
        engine.compress(huge_data);
    }, std::runtime_error);
}

int main(int argc, char **argv) {
    testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
