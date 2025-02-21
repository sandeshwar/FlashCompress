import SwiftUI
import UniformTypeIdentifiers

@MainActor
class ContentViewModel: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var isDropTargeted = false
    
    private let compressionManager = CompressionManager.shared
    
    func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        
        guard panel.runModal() == .OK else { return }
        
        let newItems = panel.urls.map { FileItem(url: $0) }
        items.append(contentsOf: newItems)
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        Task {
            for provider in providers {
                if let url = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? URL {
                    await MainActor.run {
                        self.items.append(FileItem(url: url))
                    }
                }
            }
        }
    }
    
    func compress() {
        guard !items.isEmpty else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "Compressed.zip"
        
        guard panel.runModal() == .OK,
              let destinationURL = panel.url else { return }
        
        // Mark all items as processing
        items = items.map { item in
            var newItem = item
            newItem.isProcessing = true
            return newItem
        }
        
        // Compress each item
        Task {
            for (index, item) in items.enumerated() {
                do {
                    try await compressionManager.compressFile(at: item.url, to: destinationURL) { progress in
                        Task { @MainActor in
                            self.items[index].progress = progress
                        }
                    }
                    await MainActor.run {
                        self.items[index].isProcessing = false
                        self.items[index].status = .completed
                    }
                } catch {
                    await MainActor.run {
                        self.items[index].isProcessing = false
                        self.items[index].status = .failed(error)
                    }
                }
            }
        }
    }
    
    func cancelCompression() {
        Task {
            // TODO: Implement actual cancellation in CompressionManager
            await MainActor.run {
                items = items.map { item in
                    var newItem = item
                    newItem.isProcessing = false
                    return newItem
                }
            }
        }
    }
}

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    var isProcessing: Bool = false
    var progress: Double = 0
    var status: CompressionStatus = .pending
    
    var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
    
    var sizeString: String {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return "Unknown size"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        
        return formatter.string(fromByteCount: Int64(size))
    }
}

enum CompressionStatus: Equatable {
    case pending
    case completed
    case failed(Error)
    
    static func == (lhs: CompressionStatus, rhs: CompressionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending):
            return true
        case (.completed, .completed):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
} 