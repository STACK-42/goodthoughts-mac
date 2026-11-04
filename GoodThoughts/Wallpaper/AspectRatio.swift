import CoreGraphics
import Foundation

/// A wallpaper aspect ratio named as in the feed, such as "16x10".
/// Any "WxH" key is understood, so the site can add ratios in a minor feed version.
struct AspectRatio: Hashable, Sendable, CustomStringConvertible {
    let width: Int
    let height: Int

    init?(_ key: String) {
        let parts = key.lowercased().split(separator: "x")
        guard parts.count == 2, let width = Int(parts[0]), let height = Int(parts[1]),
              width > 0, height > 0 else { return nil }
        self.width = width
        self.height = height
    }

    var key: String { "\(width)x\(height)" }
    var description: String { key }
    var value: Double { Double(width) / Double(height) }

    /// How far apart two ratios look, measured on a log scale so 2:1 vs 1:1 counts
    /// the same as 1:1 vs 1:2.
    static func distance(_ a: Double, _ b: Double) -> Double { abs(log(a) - log(b)) }

    /// The feed key whose ratio is closest to `size`, or nil when none of the keys are
    /// ratios. Ties go to the wider ratio so the choice is stable.
    static func closestKey(to size: CGSize, among keys: some Sequence<String>) -> String? {
        guard size.width > 0, size.height > 0 else { return nil }
        let target = Double(size.width / size.height)
        return keys
            .compactMap { key in AspectRatio(key).map { (key: key, ratio: $0) } }
            .min { lhs, rhs in
                let l = distance(lhs.ratio.value, target), r = distance(rhs.ratio.value, target)
                if abs(l - r) > 1e-9 { return l < r }
                if lhs.ratio.value != rhs.ratio.value { return lhs.ratio.value > rhs.ratio.value }
                return lhs.key < rhs.key
            }?
            .key
    }
}
