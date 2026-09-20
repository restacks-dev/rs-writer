import AppKit
import SwiftUI

/// Re:stacks colors shared by the editor, navigation and Markdown output.
enum BrandPalette {
    // Keep AccentColor.colorset in sync for native AppKit controls.
    static let lightAccentHex = "#A34F39"
    static let darkAccentHex = "#E99A83"
    static let lightSelectionHex = "#F1D4C8"
    static let darkSelectionHex = "#63392F"

    static let nsAccent = adaptive(light: lightAccentHex, dark: darkAccentHex)
    static let nsSelection = adaptive(light: lightSelectionHex, dark: darkSelectionHex)
    static let accent = Color(nsColor: nsAccent)

    private static func adaptive(light: String, dark: String) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = UInt32((isDark ? dark : light).dropFirst(), radix: 16)!
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }
}
