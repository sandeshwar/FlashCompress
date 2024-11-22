// #include "gpuzip.cuh"
// #include <iostream>
// #include <fstream>
// #include <vector>
// #include <string>
// #include <chrono>

// void printUsage() {
//     std::cout << "Usage: gpuzip [compress|decompress] input_file output_file\n";
// }

// bool readFile(const char* path, std::vector<uint8_t>& data) {
//     std::ifstream file(path, std::ios::binary);
//     if (!file) {
//         std::cerr << "Error: Cannot open input file: " << path << "\n";
//         return false;
//     }
    
//     file.seekg(0, std::ios::end);
//     size_t size = file.tellg();
//     file.seekg(0, std::ios::beg);
    
//     data.resize(size);
//     file.read(reinterpret_cast<char*>(data.data()), size);
//     return true;
// }

// bool writeFile(const char* path, const std::vector<uint8_t>& data) {
//     std::ofstream file(path, std::ios::binary);
//     if (!file) {
//         std::cerr << "Error: Cannot create output file: " << path << "\n";
//         return false;
//     }
    
//     file.write(reinterpret_cast<const char*>(data.data()), data.size());
//     return true;
// }

// int main(int argc, char* argv[]) {
//     if (argc != 4) {
//         printUsage();
//         return 1;
//     }

//     std::string mode = argv[1];
//     const char* input_path = argv[2];
//     const char* output_path = argv[3];

//     // Initialize CUDA
//     cudaError_t cuda_status = cudaSetDevice(0);
//     if (cuda_status != cudaSuccess) {
//         std::cerr << "Error: CUDA device initialization failed: "
//                   << cudaGetErrorString(cuda_status) << "\n";
//         return 1;
//     }

//     // Set compression parameters
//     CompressionParams params{
//         .block_size = BLOCK_SIZE,
//         .dictionary_size = DICTIONARY_SIZE,
//         .compression_level = 9.0f
//     };

//     bool success;
//     auto start_time = std::chrono::high_resolution_clock::now();

//     if (mode == "compress") {
//         success = compressFile(input_path, output_path, params);
//     } else if (mode == "decompress") {
//         success = decompressFile(input_path, output_path);
//     } else {
//         std::cerr << "Error: Invalid mode. Use 'compress' or 'decompress'\n";
//         printUsage();
//         return 1;
//     }

//     auto end_time = std::chrono::high_resolution_clock::now();
//     auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);

//     if (success) {
//         std::cout << "Operation completed successfully in " << duration.count() << "ms\n";
//         return 0;
//     } else {
//         std::cerr << "Operation failed\n";
//         return 1;
//     }
// }
