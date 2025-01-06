import XCTest
@testable import FlashCompress

final class CompressionTests: XCTestCase {
    let testManager = CompressionManager.shared
    let tempDirectory = FileManager.default.temporaryDirectory
    
    // Test data sizes
    let smallSize = 1024        // 1KB
    let mediumSize = 1024 * 100 // 100KB
    let largeSize = 1024 * 1024 // 1MB
    
    override func setUp() {
        super.setUp()
        // Setup code if needed
    }
    
    override func tearDown() {
        // Clean up temporary files
        try? FileManager.default.removeItem(at: tempDirectory.appendingPathComponent("test.txt"))
        try? FileManager.default.removeItem(at: tempDirectory.appendingPathComponent("test.flashzip"))
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestFile(size: Int, pattern: String = "Hello, World! ") -> URL {
        let fileURL = tempDirectory.appendingPathComponent("test.txt")
        let pattern = Array(pattern.utf8)
        var content: [UInt8] = []
        
        while content.count < size {
            content.append(contentsOf: pattern)
        }
        content = Array(content.prefix(size))
        
        try! Data(content).write(to: fileURL)
        return fileURL
    }
    
    private func verifyCompressedFile(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        
        // Verify file signature
        let signature = String(data: data.prefix(4), encoding: .utf8)
        XCTAssertEqual(signature, "FZIP", "Invalid file signature")
        
        // Verify version
        let version = data[4...7].withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(version, 1, "Invalid version number")
        
        // Verify minimum file size (header size)
        XCTAssertGreaterThan(data.count, 24, "File too small to be valid")
    }
    
    // MARK: - Tests
    
    func testCompressSmallFile() throws {
        let expectation = XCTestExpectation(description: "Compress small file")
        let sourceURL = createTestFile(size: smallSize)
        let destURL = tempDirectory.appendingPathComponent("test.flashzip")
        
        testManager.compressFile(at: sourceURL, to: destURL) { progress in
            // Progress updates
        } completion: { result in
            switch result {
            case .success(let url):
                do {
                    try self.verifyCompressedFile(url)
                    let compressedSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as! UInt64
                    XCTAssertLessThan(compressedSize, UInt64(self.smallSize), "Compression did not reduce file size")
                } catch {
                    XCTFail("Failed to verify compressed file: \(error)")
                }
            case .failure(let error):
                XCTFail("Compression failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCompressMediumFile() throws {
        let expectation = XCTestExpectation(description: "Compress medium file")
        let sourceURL = createTestFile(size: mediumSize)
        let destURL = tempDirectory.appendingPathComponent("test.flashzip")
        
        testManager.compressFile(at: sourceURL, to: destURL) { progress in
            // Progress updates
        } completion: { result in
            switch result {
            case .success(let url):
                do {
                    try self.verifyCompressedFile(url)
                    let compressedSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as! UInt64
                    XCTAssertLessThan(compressedSize, UInt64(self.mediumSize), "Compression did not reduce file size")
                } catch {
                    XCTFail("Failed to verify compressed file: \(error)")
                }
            case .failure(let error):
                XCTFail("Compression failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCompressLargeFile() throws {
        let expectation = XCTestExpectation(description: "Compress large file")
        let sourceURL = createTestFile(size: largeSize)
        let destURL = tempDirectory.appendingPathComponent("test.flashzip")
        
        testManager.compressFile(at: sourceURL, to: destURL) { progress in
            XCTAssertGreaterThanOrEqual(progress, 0.0)
            XCTAssertLessThanOrEqual(progress, 1.0)
        } completion: { result in
            switch result {
            case .success(let url):
                do {
                    try self.verifyCompressedFile(url)
                    let compressedSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as! UInt64
                    XCTAssertLessThan(compressedSize, UInt64(self.largeSize), "Compression did not reduce file size")
                } catch {
                    XCTFail("Failed to verify compressed file: \(error)")
                }
            case .failure(let error):
                XCTFail("Compression failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testInvalidInput() {
        let expectation = XCTestExpectation(description: "Test invalid input")
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/path.txt")
        let destURL = tempDirectory.appendingPathComponent("test.flashzip")
        
        testManager.compressFile(at: nonExistentURL, to: destURL) { _ in
        } completion: { result in
            switch result {
            case .success:
                XCTFail("Should not succeed with invalid input")
            case .failure(let error):
                XCTAssertTrue(error is CompressionError)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCompressionParameters() throws {
        let sourceURL = createTestFile(size: smallSize)
        let destURL = tempDirectory.appendingPathComponent("test.flashzip")
        let expectation = XCTestExpectation(description: "Test compression parameters")
        
        testManager.compressFile(at: sourceURL, to: destURL) { _ in
        } completion: { result in
            switch result {
            case .success(let url):
                do {
                    let data = try Data(contentsOf: url)
                    
                    // Verify header parameters
                    let windowSize = data[8...11].withUnsafeBytes { $0.load(as: UInt32.self) }
                    let minMatchLength = data[12...15].withUnsafeBytes { $0.load(as: UInt32.self) }
                    let maxMatchLength = data[16...19].withUnsafeBytes { $0.load(as: UInt32.self) }
                    let dictionarySize = data[20...23].withUnsafeBytes { $0.load(as: UInt32.self) }
                    
                    XCTAssertEqual(windowSize, 32768)
                    XCTAssertEqual(minMatchLength, 3)
                    XCTAssertEqual(maxMatchLength, 258)
                    XCTAssertEqual(dictionarySize, 4096)
                } catch {
                    XCTFail("Failed to verify compression parameters: \(error)")
                }
            case .failure(let error):
                XCTFail("Compression failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
