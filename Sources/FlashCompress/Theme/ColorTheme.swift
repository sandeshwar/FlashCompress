import SwiftUI

enum ColorTheme {
    static let primary = Color(hex: "#FFC107")    // Amber/Gold - Vibrant accent color
    static let secondary = Color(hex: "#64B5F6")  // Light Blue - Secondary accent
    static let accent = Color(hex: "#FF5733")     // Vivid Orange-Red - Call to action
    static let background = Color(hex: "#1E1E1E") // Dark gray - Main background
    static let cardBackground = Color(hex: "#2D2D2D") // Slightly lighter background for cards
    static let text = Color(hex: "#FFFFFF")       // White - Primary text
    static let textSecondary = Color(hex: "#9E9E9E") // Gray - Secondary text
    static let success = Color(hex: "#4CAF50")    // Green - Success indicators
    static let warning = Color(hex: "#FFEB3B")    // Yellow - Warning indicators
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 
