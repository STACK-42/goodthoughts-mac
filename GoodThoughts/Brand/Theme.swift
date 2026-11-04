import AppKit
import SwiftUI

/// Colour roles for the app's UI, in light and dark appearance.
/// Light values come straight from the palette. The brand reference defines no dark
/// theme, so dark mode swaps paper and ink and uses the icon reference's dark ground
/// (#1E1E1C). The highlighter stays the only colour in both.
enum Theme {
    static let paper = adaptive(light: Palette.paperHex, dark: "#1E1E1C")
    static let ink = adaptive(light: Palette.inkHex, dark: Palette.paperHex)
    static let card = adaptive(light: Palette.cardHex, dark: Palette.inkHex)
    /// Secondary text.
    static let muted = adaptive(light: "#5C5C5C", dark: "#8A8A85")
    /// Tertiary text and placeholders.
    static let faint = adaptive(light: "#8A8A85", dark: "#5C5C5C")
    /// Hairlines.
    static let rule = adaptive(light: "#E2E2DC", dark: "#3D3D3D")
    static let wash = adaptive(light: "#EFEFEA", dark: "#2B2B2B")
    static let highlighter = Palette.highlighter
    /// Text on the highlighter is always dark ink, whatever the appearance.
    static let onHighlighter = Palette.ink

    static func adaptive(light: String, dark: String) -> Color {
        _ = (nsColor(light), nsColor(dark)) // fail fast on a bad hex
        return Color(nsColor: NSColor(name: nil) { appearance in
            nsColor(appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        })
    }

    private static func nsColor(_ hex: String) -> NSColor {
        guard let rgb = RGB(hex: hex) else { preconditionFailure("Bad hex \(hex)") }
        return NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}
