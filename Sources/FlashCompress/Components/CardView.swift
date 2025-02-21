import SwiftUI

struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(24)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 16,
                x: 0,
                y: 8
            )
    }
}

struct FileCard: View {
    let fileName: String
    let fileSize: String
    let compressionRatio: Double?
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ColorTheme.primary)
                        .frame(width: 40, height: 40)
                        .background(ColorTheme.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ColorTheme.text)
                        
                        Text(fileSize)
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.text.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    if let ratio = compressionRatio {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(ColorTheme.success)
                            Text("\(Int(ratio * 100))%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ColorTheme.success)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ColorTheme.success.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
} 