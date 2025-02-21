import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var isCompressing = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            if isCompressing {
                CompressionProgressView(
                    progress: viewModel.overallProgress,
                    currentFileName: viewModel.currentProcessingItem?.url.lastPathComponent ?? "",
                    filesCompleted: viewModel.completedItems,
                    totalFiles: viewModel.items.count
                ) {
                    withAnimation {
                        isCompressing = false
                        viewModel.cancelCompression()
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        dropZone
                        
                        if !viewModel.items.isEmpty {
                            fileList
                        }
                    }
                    .padding()
                }
            }
            
            if !viewModel.items.isEmpty && !isCompressing {
                startCompressionButton
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(ColorTheme.background)
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FlashCompress")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ColorTheme.text)
                
                Text("Fast and efficient file compression")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: viewModel.addFiles) {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundColor(ColorTheme.primary)
            }
            .buttonStyle(.plain)
            .padding(8)
            .background(Color.white)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.1), radius: 4)
        }
        .padding()
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
    
    private var dropZone: some View {
        CardView {
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 40))
                    .foregroundColor(viewModel.isDropTargeted ? ColorTheme.primary : .gray)
                
                Text("Drag and drop files here")
                    .font(.headline)
                    .foregroundColor(ColorTheme.text)
                
                Text("or")
                    .foregroundColor(.gray)
                
                PrimaryButton(
                    title: "Select Files",
                    icon: "folder.fill.badge.plus",
                    action: viewModel.addFiles
                )
                .frame(maxWidth: 200)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
        }
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isDropTargeted) { providers in
            viewModel.handleDrop(providers: providers)
            return true
        }
    }
    
    private var fileList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Files")
                .font(.headline)
                .foregroundColor(ColorTheme.text)
            
            ForEach(viewModel.items) { item in
                FileCard(
                    fileName: item.url.lastPathComponent,
                    fileSize: item.sizeString,
                    compressionRatio: item.status == .completed ? 0.7 : nil // TODO: Add actual compression ratio
                )
            }
        }
    }
    
    private var startCompressionButton: some View {
        PrimaryButton(
            title: "Start Compression",
            icon: "bolt.fill"
        ) {
            withAnimation {
                isCompressing = true
                viewModel.compress()
            }
        }
        .padding()
    }
}

extension ContentViewModel {
    var overallProgress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(completedItems) / Double(items.count)
    }
    
    var completedItems: Int {
        items.filter { $0.status == .completed }.count
    }
    
    var currentProcessingItem: FileItem? {
        items.first { $0.isProcessing }
    }
    
    func cancelCompression() {
        // TODO: Implement compression cancellation
        items = items.map { item in
            var newItem = item
            newItem.isProcessing = false
            return newItem
        }
    }
} 