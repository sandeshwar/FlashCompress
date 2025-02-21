import SwiftUI

struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

struct FileCard: View {
    let fileName: String
    let fileSize: String
    let compressionRatio: Double?
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(ColorTheme.primary)
                    Text(fileName)
                        .fontWeight(.medium)
                        .foregroundColor(ColorTheme.text)
                    Spacer()
                    Text(fileSize)
                        .foregroundColor(.gray)
                        .font(.footnote)
                }
                
                if let ratio = compressionRatio {
                    HStack {
                        Text("Compression:")
                            .foregroundColor(.gray)
                        Text("\(Int(ratio * 100))%")
                            .foregroundColor(ColorTheme.success)
                            .fontWeight(.semibold)
                    }
                    .font(.footnote)
                }
            }
        }
    }
} 