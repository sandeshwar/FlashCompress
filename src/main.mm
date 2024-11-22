#include <iostream>
#include <fstream>
#include <vector>
#include <chrono>
#include "CompressionEngine.mm"

void printUsage() {
    std::cout << "Usage: gpuzip [compress|decompress] input_file output_file\n";
}

bool readFile(const std::string& path, std::vector<uint8_t>& data) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        std::cerr << "Error: Cannot open input file: " << path << "\n";
        return false;
    }
    
    file.seekg(0, std::ios::end);
    size_t size = file.tellg();
    file.seekg(0, std::ios::beg);
    
    data.resize(size);
    file.read(reinterpret_cast<char*>(data.data()), size);
    return true;
}

bool writeFile(const std::string& path, const std::vector<uint8_t>& data) {
    std::ofstream file(path, std::ios::binary);
    if (!file) {
        std::cerr << "Error: Cannot create output file: " << path << "\n";
        return false;
    }
    
    file.write(reinterpret_cast<const char*>(data.data()), data.size());
    return true;
}

int main(int argc, char* argv[]) {
    if (argc != 4) {
        printUsage();
        return 1;
    }
    
    std::string mode = argv[1];
    std::string input_path = argv[2];
    std::string output_path = argv[3];
    
    try {
        // Initialize compression engine
        CompressionEngine engine;
        
        // Read input file
        std::vector<uint8_t> input_data;
        if (!readFile(input_path, input_data)) {
            return 1;
        }
        
        // Process the file
        auto start_time = std::chrono::high_resolution_clock::now();
        std::vector<uint8_t> output_data;
        
        if (mode == "compress") {
            output_data = engine.compress(input_data);
            
            // Calculate compression ratio
            double ratio = static_cast<double>(input_data.size()) / output_data.size();
            std::cout << "Compression ratio: " << ratio << ":1\n";
            
        } else if (mode == "decompress") {
            output_data = engine.decompress(input_data);
        } else {
            std::cerr << "Error: Invalid mode. Use 'compress' or 'decompress'\n";
            printUsage();
            return 1;
        }
        
        auto end_time = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
        
        // Write output file
        if (!writeFile(output_path, output_data)) {
            return 1;
        }
        
        // Print statistics
        std::cout << "Operation completed in " << duration.count() << "ms\n";
        std::cout << "Input size: " << input_data.size() << " bytes\n";
        std::cout << "Output size: " << output_data.size() << " bytes\n";
        
        return 0;
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }
}
