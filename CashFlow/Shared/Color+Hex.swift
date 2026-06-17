import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)

        let r, g, b, a: Double
        switch normalized.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            r = 0.4; g = 0.4; b = 0.4; a = 1
        }

        self = Color(red: r, green: g, blue: b, opacity: a)
    }
}
