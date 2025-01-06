import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.items) { item in
                FileItemView(item: item)
            }
            .listStyle(.inset)
            .navigationTitle("FlashCompress")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: viewModel.addFiles) {
                        Label("Add Files", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: viewModel.compress) {
                        Label("Compress", systemImage: "arrow.down.circle")
                    }
                    .disabled(viewModel.items.isEmpty)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            viewModel.handleDrop(providers: providers)
            return true
        }
    }
}

struct FileItemView: View {
    let item: FileItem
    
    var body: some View {
        HStack {
            Image(systemName: item.isDirectory ? "folder" : "doc")
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text(item.url.lastPathComponent)
                    .font(.headline)
                
                Text(item.sizeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if item.isProcessing {
                Spacer()
                ProgressView(value: item.progress)
                    .progressViewStyle(.circular)
            } else {
                Spacer()
                switch item.status {
                case .pending:
                    Text("Pending")
                case .completed:
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                case .failed(let error):
                    Image(systemName: "xmark")
                        .foregroundColor(.red)
                    Text("Error: \(error.localizedDescription)")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

class ContentViewModel: ObservableObject {
    @Published var items: [FileItem] = []
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
        providers.forEach { provider in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                DispatchQueue.main.async {
                    self.items.append(FileItem(url: url))
                }
            }
        }
    }
    
    func compress() {
        guard !items.isEmpty else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.archive]
        panel.nameFieldStringValue = "Compressed.flashzip"
        
        guard panel.runModal() == .OK,
              let destinationURL = panel.url else { return }
        
        // Mark all items as processing
        items = items.map { item in
            var newItem = item
            newItem.isProcessing = true
            return newItem
        }
        
        // Compress each item
        for (index, item) in items.enumerated() {
            compressionManager.compressFile(at: item.url, to: destinationURL) { progress in
                DispatchQueue.main.async {
                    // Update progress for this item
                    self.items[index].progress = progress
                }
            } completion: { result in
                DispatchQueue.main.async {
                    // Mark item as complete
                    self.items[index].isProcessing = false
                    
                    switch result {
                    case .success:
                        self.items[index].status = .completed
                    case .failure(let error):
                        self.items[index].status = .failed(error)
                    }
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

enum CompressionStatus {
    case pending
    case completed
    case failed(Error)
}
