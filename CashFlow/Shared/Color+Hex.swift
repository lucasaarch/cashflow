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

    var hexString: String {
#if os(macOS)
        let resolved = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        let r = Int(round(resolved.redComponent * 255))
        let g = Int(round(resolved.greenComponent * 255))
        let b = Int(round(resolved.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
#else
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
#endif
    }
}
