import SwiftUI

enum ColorTheme {
    static let primary = Color(hex: "6C63FF")    // Vibrant purple
    static let secondary = Color(hex: "4ECDC4")  // Turquoise
    static let accent = Color(hex: "FF6B6B")     // Coral
    static let background = Color(hex: "F7F7F9") // Light gray
    static let text = Color(hex: "2C3E50")       // Dark blue-gray
    static let success = Color(hex: "2ECC71")    // Green
    static let warning = Color(hex: "F1C40F")    // Yellow
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