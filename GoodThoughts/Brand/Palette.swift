import SwiftUI

/// An sRGB colour parsed from a `#RRGGBB` string.
struct RGB: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    /// Parses `#RRGGBB` or `RRGGBB`. Returns nil for anything else.
    init?(hex: String) {
        var digits = Substring(hex)
        if digits.hasPrefix("#") { digits = digits.dropFirst() }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit),
              let value = UInt32(digits, radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}

/// The goodthoughts palette, copied from `docs/brand/HybridA.dc.html` in the site repo.
/// The highlighter is the only colour; everything else is paper, ink and greys.
enum Palette {
    static let paperHex = "#FAFAF7"
    static let inkHex = "#2B2B2B"
    static let cardHex = "#FFFFFF"
    static let highlighterHex = "#F2D649"
    /// Darkest to lightest.
    static let greyHexes = ["#3D3D3D", "#5C5C5C", "#8A8A85", "#E2E2DC", "#EFEFEA"]

    static let allHexes = [paperHex, inkHex, cardHex, highlighterHex] + greyHexes

    static let paper = rgb(paperHex).color
    static let ink = rgb(inkHex).color
    static let card = rgb(cardHex).color
    static let highlighter = rgb(highlighterHex).color

    private static func rgb(_ hex: String) -> RGB {
        guard let value = RGB(hex: hex) else { preconditionFailure("Bad palette hex \(hex)") }
        return value
    }
}
