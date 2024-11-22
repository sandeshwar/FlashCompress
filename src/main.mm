#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "CompressionEngine.h"
#include <iostream>
#include <fstream>
#include <vector>

void printUsage() {
    std::cout << "Usage: gpuzip [command] [input_file] [output_file]\n"
              << "Commands:\n"
              << "  compress   - Compress input_file to output_file\n"
              << "  decompress - Decompress input_file to output_file\n";
}

std::vector<uint8_t> readFile(const std::string& filename) {
    std::ifstream file(filename, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        throw std::runtime_error("Failed to open file: " + filename);
    }
    
    size_t size = file.tellg();
    file.seekg(0, std::ios::beg);
    
    std::vector<uint8_t> buffer(size);
    if (!file.read(reinterpret_cast<char*>(buffer.data()), size)) {
        throw std::runtime_error("Failed to read file: " + filename);
    }
    
    return buffer;
}

void writeFile(const std::string& filename, const std::vector<uint8_t>& data) {
    std::ofstream file(filename, std::ios::binary);
    if (!file.is_open()) {
        throw std::runtime_error("Failed to open file for writing: " + filename);
    }
    
    if (!file.write(reinterpret_cast<const char*>(data.data()), data.size())) {
        throw std::runtime_error("Failed to write file: " + filename);
    }
}

int main(int argc, const char* argv[]) {
    @autoreleasepool {
        if (argc != 4) {
            printUsage();
            return 1;
        }
        
        std::string command = argv[1];
        std::string input_file = argv[2];
        std::string output_file = argv[3];
        
        try {
            CompressionEngine engine;
            std::vector<uint8_t> input_data = readFile(input_file);
            std::vector<uint8_t> output_data;
            
            if (command == "compress") {
                std::cout << "Compressing " << input_file << " to " << output_file << "...\n";
                output_data = engine.compress(input_data);
                std::cout << "Compressed size: " << output_data.size() << " bytes "
                         << "(ratio: " << (float)output_data.size() / input_data.size() * 100 << "%)\n";
            }
            else if (command == "decompress") {
                std::cout << "Decompressing " << input_file << " to " << output_file << "...\n";
                output_data = engine.decompress(input_data);
                std::cout << "Decompressed size: " << output_data.size() << " bytes\n";
            }
            else {
                printUsage();
                return 1;
            }
            
            writeFile(output_file, output_data);
            std::cout << "Operation completed successfully.\n";
            
        } catch (const std::exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
            return 1;
        }
        
        return 0;
    }
}
