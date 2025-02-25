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
                .padding()
                .transition(.opacity)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        dropZone
                        
                        if !viewModel.items.isEmpty {
                            fileList
                        }
                    }
                    .padding(24)
                }
            }
            
            if !viewModel.items.isEmpty && !isCompressing {
                startCompressionButton
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(ColorTheme.background)
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FlashCompress")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ColorTheme.text)
                
                Text("Fast and efficient file compression")
                    .font(.system(size: 16))
                    .foregroundColor(ColorTheme.text.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: viewModel.addFiles) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(ColorTheme.primary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .shadow(color: ColorTheme.primary.opacity(0.3), radius: 8)
        }
        .padding(24)
        .background(.white)
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
    
    private var dropZone: some View {
        CardView {
            VStack(spacing: 24) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 48))
                    .foregroundColor(viewModel.isDropTargeted ? ColorTheme.primary : ColorTheme.text.opacity(0.3))
                
                VStack(spacing: 8) {
                    Text("Drag and drop files here")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(ColorTheme.text)
                    
                    Text("or")
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.text.opacity(0.6))
                }
                
                PrimaryButton(
                    title: "Select Files",
                    icon: "folder.fill.badge.plus",
                    action: viewModel.addFiles
                )
                .frame(maxWidth: 200)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        viewModel.isDropTargeted ? ColorTheme.primary : Color.clear,
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )
            )
        }
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isDropTargeted) { providers in
            viewModel.handleDrop(providers: providers)
            return true
        }
    }
    
    private var fileList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Selected Files")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTheme.text)
            
            ForEach(viewModel.items) { item in
                FileCard(
                    fileName: item.url.lastPathComponent,
                    fileSize: item.sizeString,
                    compressionRatio: item.status == .completed ? 0.7 : nil
                )
                .transition(.opacity)
            }
        }
    }
    
    private var startCompressionButton: some View {
        PrimaryButton(
            title: "Start Compression",
            icon: "bolt.fill"
        ) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isCompressing = true
                viewModel.compress()
            }
        }
        .padding(24)
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
} 