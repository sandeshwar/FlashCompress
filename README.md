# FlashCompress

FlashCompress is a high-performance file compression and decompression utility specifically designed for macOS, leveraging Metal GPU acceleration for optimal performance. It provides lightning-fast compression speeds while maintaining excellent compression ratios.

## Features

- 🚀 GPU-accelerated compression and decompression using Metal
- 💻 Native macOS experience with SwiftUI interface
- 🎯 Drag-and-drop support for easy file handling
- ⚡ Parallel processing for maximum performance
- 🔧 Customizable compression settings
- 📊 Real-time progress monitoring
- 🔒 Secure file handling

## Requirements

### Minimum Requirements
- macOS 13.0 or later
- Metal-capable GPU
- 8GB RAM
- 2GB free storage

### Recommended
- macOS 14.0 or later
- Apple Silicon or dedicated GPU
- 16GB RAM
- 4GB free storage

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/FlashCompress.git
cd FlashCompress
```

2. Install dependencies using Swift Package Manager:
```bash
swift package resolve
```

3. Open the project in Xcode:
```bash
xed .
```

4. Build and run the project

## Development Setup

1. Install Xcode 15.0 or later
2. Install the latest Command Line Tools
3. Ensure Metal Developer Tools are installed

## Project Structure

```
FlashCompress/
├── Sources/
│   ├── App/                    # Main application code
│   ├── Core/                   # Core compression engine
│   ├── Metal/                  # Metal compute kernels
│   └── UI/                     # SwiftUI interface
├── Tests/                      # Test suites
├── Resources/                  # Assets and resources
└── Package.swift              # Swift package manifest
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Apple Metal Framework
- Swift and SwiftUI teams
- Contributors and maintainers

## Documentation

For detailed technical information, please refer to the [ARCHITECTURE.md](ARCHITECTURE.md) document.
