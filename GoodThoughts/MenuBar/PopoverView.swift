import SwiftUI

/// The window that drops down from the menu bar icon.
/// Plain layout for now; round 5 brings the real design.
struct PopoverView: View {
    static let width: CGFloat = 320

    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack {
                Text(statusLine)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: Self.width)
        .task { await model.refresh() }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView().controlSize(.small)
        case .failed(let error):
            message(error)
        case .ready(let loaded):
            VStack(alignment: .leading, spacing: 10) {
                if loaded.updateRequired {
                    message(.unsupportedVersion(""))
                }
                if let quote = model.todaysQuote {
                    QuoteSummary(quote: quote)
                } else {
                    Text("The feed has no quotes yet.").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func message(_ error: FeedError) -> some View {
        Text(error.errorDescription ?? "Something went wrong.")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var statusLine: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        switch model.feed?.source {
        case .network?: return "v\(version)"
        case .cache?: return "v\(version) · offline, saved quotes"
        case .sample?: return "v\(version) · sample feed"
        case nil: return "v\(version)"
        }
    }
}

private struct QuoteSummary: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: quote.language.isRightToLeft ? .trailing : .leading, spacing: 8) {
            Text(quote.number.uppercased())
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(quote.text)
                .font(.system(size: 17, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.layoutDirection, quote.language.isRightToLeft ? .rightToLeft : .leftToRight)
                .frame(maxWidth: .infinity, alignment: quote.language.isRightToLeft ? .trailing : .leading)
                .multilineTextAlignment(quote.language.isRightToLeft ? .trailing : .leading)
            if !byline.isEmpty {
                Text(byline)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var byline: String {
        [quote.author, quote.source].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
