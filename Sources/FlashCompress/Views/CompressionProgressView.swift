import SwiftUI

struct CompressionProgressView: View {
    let progress: Double
    let currentFileName: String
    let filesCompleted: Int
    let totalFiles: Int
    let onCancel: () -> Void
    
    var body: some View {
        CardView {
            VStack(spacing: 24) {
                progressIndicator
                fileInfo
                cancelButton
            }
        }
        .padding()
    }
    
    private var progressIndicator: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(ColorTheme.primary.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ColorTheme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(progress * 100))%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ColorTheme.primary)
            }
            
            Text("\(filesCompleted) of \(totalFiles) files completed")
                .foregroundColor(.gray)
        }
    }
    
    private var fileInfo: some View {
        VStack(spacing: 8) {
            Text("Currently Processing:")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(currentFileName)
                .font(.headline)
                .foregroundColor(ColorTheme.text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
    
    private var cancelButton: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .foregroundColor(ColorTheme.accent)
                .fontWeight(.medium)
        }
    }
} 