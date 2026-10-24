import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

enum SubjectPalette {
    static let hexes = [
        "#4F6DF2", "#8B5CF6", "#EC4899", "#EF4444", "#F97316",
        "#EAB308", "#22C55E", "#14B8A6", "#06B6D4", "#64748B"
    ]
}
