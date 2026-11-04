import AppKit
import CoreText
import SwiftUI

/// The bundled brand fonts (all SIL OFL, licences beside them in Resources).
enum BrandFont: String, CaseIterable {
    /// Quote text.
    case garamond = "EBGaramond-Regular"
    /// Headings and the wordmark.
    case instrument = "InstrumentSerif-Regular"
    /// Metadata and UI.
    case mono = "JetBrainsMono-Regular"
    case monoMedium = "JetBrainsMonoRoman-Medium"
    /// Arabic, since the others have no Arabic glyphs.
    case amiri = "Amiri-Regular"

    static let files = [
        "EBGaramond-Variable", "InstrumentSerif-Regular", "JetBrainsMono-Variable", "Amiri-Regular",
    ]

    /// Registers the fonts for this process. Safe to call more than once.
    @discardableResult
    static func registerAll(in bundle: Bundle = .main) -> [String] {
        var missing: [String] = []
        for name in files {
            guard let url = bundle.url(forResource: name, withExtension: "ttf") else {
                missing.append(name)
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already registered is fine; anything else is a missing font.
                let code = (error?.takeRetainedValue()).map { CFErrorGetCode($0) }
                if code != CTFontManagerError.alreadyRegistered.rawValue { missing.append(name) }
            }
        }
        return missing
    }

    func font(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(rawValue, size: size, relativeTo: style)
    }
}

/// Type roles from the brand reference (HybridA).
enum Typography {
    /// Uppercase mono labels: about 0.1em tracking.
    static func label(_ size: CGFloat = 10) -> Font { BrandFont.monoMedium.font(size, relativeTo: .caption2) }
    static func labelTracking(_ size: CGFloat = 10) -> CGFloat { size * 0.1 }
    static func meta(_ size: CGFloat = 12) -> Font { BrandFont.mono.font(size, relativeTo: .caption) }
    static func heading(_ size: CGFloat = 22) -> Font { BrandFont.instrument.font(size, relativeTo: .title2) }

    /// Quote text. Arabic gets Amiri, a touch larger, with more leading and no tracking.
    static func quote(rightToLeft: Bool, size: CGFloat = 19) -> Font {
        rightToLeft ? BrandFont.amiri.font(size + 1, relativeTo: .title3) : BrandFont.garamond.font(size, relativeTo: .title3)
    }

    static func quoteLineSpacing(rightToLeft: Bool) -> CGFloat { rightToLeft ? 6 : 3 }

    /// Names in metadata use Amiri when they're written in Arabic script.
    static func metaValue(_ text: String, size: CGFloat = 12) -> Font {
        text.containsArabic ? BrandFont.amiri.font(size + 2, relativeTo: .caption) : meta(size)
    }
}

extension String {
    var containsArabic: Bool {
        unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) || (0x0750...0x077F).contains($0.value)
            || (0xFB50...0xFDFF).contains($0.value) || (0xFE70...0xFEFF).contains($0.value) }
    }
}
