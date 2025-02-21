import SwiftUI

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let isLoading: Bool
    
    init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                }
                
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isLoading ? ColorTheme.primary.opacity(0.8) : ColorTheme.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: ColorTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading)
    }
} 