import SwiftUI

/// The window that drops down from the menu bar icon.
/// Placeholder content until the feed and the real layout arrive.
struct PopoverView: View {
    static let width: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("goodthoughts")
                    .font(.system(size: 22, design: .serif))
                Text("Today's quote will appear here.")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            HStack {
                Text("v\(Self.version)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: Self.width)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
