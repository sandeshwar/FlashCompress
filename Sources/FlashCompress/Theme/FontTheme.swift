import SwiftUI

enum FontTheme {
    static let title = Font.system(size: 32, weight: .heavy, design: .rounded)
    static let subtitle = Font.system(size: 16, design: .rounded)
    static let body = Font.system(size: 16, design: .rounded)
    static let caption = Font.system(size: 14, design: .rounded)
    
    // Icon sizes
    static let largeIcon = Font.system(size: 48)
    static let mediumIcon = Font.system(size: 32)
    static let smallIcon = Font.system(size: 20)
} 