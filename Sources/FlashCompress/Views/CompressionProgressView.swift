import SwiftUI

struct CompressionProgressView: View {
    let progress: Double
    let currentFileName: String
    let filesCompleted: Int
    let totalFiles: Int
    let onCancel: () -> Void
    
    var body: some View {
        CardView {
            VStack(spacing: 32) {
                progressIndicator
                fileInfo
                cancelButton
            }
            .frame(maxWidth: .infinity)
            .frame(height: 400)
        }
    }
    
    private var progressIndicator: some View {
        VStack(spacing: 24) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(
                        ColorTheme.primary.opacity(0.1),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                ColorTheme.primary,
                                ColorTheme.primary.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                
                // Progress text
                VStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(FontTheme.title)
                        .foregroundColor(ColorTheme.primary)
                    
                    Text("Complete")
                        .font(FontTheme.body)
                        .foregroundColor(ColorTheme.text.opacity(0.6))
                }
            }
            
            Text("\(filesCompleted) of \(totalFiles) files completed")
                .font(FontTheme.body)
                .foregroundColor(ColorTheme.text.opacity(0.6))
        }
    }
    
    private var fileInfo: some View {
        VStack(spacing: 12) {
            Text("Currently Processing")
                .font(FontTheme.body)
                .foregroundColor(ColorTheme.text.opacity(0.6))
            
            HStack(spacing: 12) {
                Image(systemName: "doc.fill")
                    .font(FontTheme.smallIcon)
                    .foregroundColor(ColorTheme.primary)
                    .frame(width: 40, height: 40)
                    .background(ColorTheme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(currentFileName)
                    .font(FontTheme.body.weight(.medium))
                    .foregroundColor(ColorTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(ColorTheme.cardBackground)
            .cornerRadius(12)
            .shadow(
                color: Color.black.opacity(0.2),
                radius: 8,
                x: 0,
                y: 4
            )
        }
    }
    
    private var cancelButton: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(FontTheme.body.weight(.medium))
                .foregroundColor(ColorTheme.accent)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(ColorTheme.accent.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
} 