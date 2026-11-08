import SwiftUI

/// The window that drops down from the menu bar icon. Values follow the brand
/// reference (HybridA): paper ground, ink hairlines, mono labels, the highlighter
/// as the only colour.
struct PopoverView: View {
    static let width: CGFloat = 360
    static let gutter: CGFloat = 16

    @ObservedObject var model: AppModel
    @ObservedObject var updater: Updater
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var dayOffset: Int { model.dayOffset }
    private var day: Int { model.todayNumber + dayOffset }
    private var quote: Quote? { model.quote(forDay: day) }

    var body: some View {
        VStack(spacing: 0) {
            Header(number: quote?.number, showingSettings: model.showingSettings, toggleSettings: toggleSettings)
            if model.showingSettings {
                SettingsPage(model: model)
                    .transition(.opacity)
            } else {
                content
                    .transition(.opacity)
            }
            Footer(status: statusLine, updater: updater)
        }
        .frame(width: Self.width)
        .background(Theme.paper)
        .foregroundStyle(Theme.ink)
        .task {
            model.refreshLoginItem()
            await model.refreshReminderAuthorization()
            await model.dayMayHaveChanged()
        }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: 160)
        case .failed(let error):
            Notice(text: error.errorDescription ?? "Something went wrong.")
                .padding(Self.gutter)
        case .ready(let loaded):
            VStack(alignment: .leading, spacing: 14) {
                DayNavigator(label: dayLabel, isToday: dayOffset == 0, move: move)
                if loaded.updateRequired {
                    Notice(text: FeedError.unsupportedVersion("").errorDescription ?? "")
                }
                if let quote {
                    VStack(alignment: .leading, spacing: 14) {
                        WallpaperPreview(quote: quote, model: model)
                        QuoteText(quote: quote)
                        Byline(quote: quote)
                        if let url = quote.url { QuoteLink(url: url) }
                        ApplyControls(model: model, quote: quote)
                    }
                    .id(quote.id)
                    .transition(.opacity)
                } else {
                    Text("The feed has no quotes yet.")
                        .font(Typography.meta())
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(Self.gutter)
        }
    }

    private func toggleSettings() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
            model.showingSettings.toggle()
        }
    }

    private func move(_ step: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            model.dayOffset = step == 0 ? 0 : dayOffset + step
        }
    }

    private var dayLabel: String {
        switch dayOffset {
        case 0: return "Today"
        case -1: return "Yesterday"
        case 1: return "Tomorrow"
        default:
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
            return formatter.string(from: model.date(forDay: day))
        }
    }

    private var statusLine: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        switch model.feed?.source {
        case .cache?: return "v\(version) · offline, saved quotes"
        case .sample?: return "v\(version) · sample feed"
        default: return "v\(version)"
        }
    }
}

// MARK: - Pieces

/// An uppercase mono label with the brand's 0.1em tracking.
private struct Label: View {
    let text: String
    var size: CGFloat = 10
    var color: Color = Theme.muted

    var body: some View {
        Text(text.uppercased())
            .font(Typography.label(size))
            .tracking(Typography.labelTracking(size))
            .foregroundStyle(color)
    }
}

private struct Hairline: View {
    var color: Color = Theme.rule
    var body: some View { Rectangle().fill(color).frame(height: 1) }
}

/// "good" + "thoughts" on the highlighter, the catalogue number in a ruled tag, and
/// the button that swaps between the quote and the settings page.
private struct Header: View {
    let number: String?
    let showingSettings: Bool
    let toggleSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 0) {
                    Text("good")
                    Text("thoughts")
                        .foregroundStyle(Theme.onHighlighter)
                        .padding(.horizontal, 3)
                        .background(Theme.highlighter)
                }
                .font(Typography.heading(26))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("goodthoughts")
                Spacer()
                if showingSettings {
                    Label(text: "Settings", size: 11, color: Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                } else if let number, !number.isEmpty {
                    Text(number)
                        .font(Typography.label(11))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))
                        .accessibilityLabel("Number \(number.replacingOccurrences(of: "No. ", with: ""))")
                }
                Button(action: toggleSettings) {
                    Image(systemName: showingSettings ? "xmark" : "gearshape")
                        .font(.system(size: showingSettings ? 11 : 13, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(showingSettings ? .cancelAction : KeyboardShortcut(",", modifiers: .command))
                .accessibilityLabel(showingSettings ? "Close settings" : "Settings")
                .help(showingSettings ? "Back to the quote" : "Settings (⌘,)")
            }
            .padding(.horizontal, PopoverView.gutter)
            .padding(.top, 14)
            .padding(.bottom, 12)
            Hairline(color: Theme.ink)
        }
    }
}

private struct DayNavigator: View {
    let label: String
    let isToday: Bool
    let move: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            arrow("chevron.left", "Previous day", step: -1, key: .leftArrow)
            Label(text: label, size: 11, color: Theme.ink)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            arrow("chevron.right", "Next day", step: 1, key: .rightArrow)
        }
        .overlay(alignment: .trailing) {
            if !isToday {
                Button { move(0) } label: { Label(text: "Today", color: Theme.muted) }
                    .buttonStyle(.plain)
                    .keyboardShortcut("t", modifiers: [])
                    .padding(.trailing, 28)
                    .help("Back to today")
            }
        }
    }

    private func arrow(_ symbol: String, _ name: String, step: Int, key: KeyEquivalent) -> some View {
        Button { move(step) } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(key, modifiers: [])
        .accessibilityLabel(name)
        .help(name)
    }
}

/// The site's wallpaper for the main screen, downloaded through the same cache Apply uses.
private struct WallpaperPreview: View {
    let quote: Quote
    @ObservedObject var model: AppModel
    // @StateObject, not @State: @State is a macro in newer SDKs, which the
    // Command Line Tools build in scripts/run.sh can't expand.
    @StateObject private var preview = PreviewState()

    var body: some View {
        ZStack {
            Theme.wash
            if let image = preview.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if preview.failed {
                Label(text: "No preview", color: Theme.faint)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .aspectRatio(preview.ratio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))
        .accessibilityElement()
        .accessibilityLabel("Wallpaper preview")
        .task(id: quote.id) { await preview.load(quote, from: model) }
    }
}

@MainActor
private final class PreviewState: ObservableObject {
    @Published var image: NSImage?
    @Published var ratio: Double = 16.0 / 10.0
    @Published var failed = false

    func load(_ quote: Quote, from model: AppModel) async {
        image = nil
        failed = false
        if let found = await model.previewFile(for: quote) {
            ratio = found.ratio.value
            image = NSImage(contentsOf: found.file)
            failed = image == nil
        } else {
            failed = true
        }
    }
}

/// The quote in EB Garamond, or Amiri laid out right to left for Arabic.
private struct QuoteText: View {
    let quote: Quote

    var body: some View {
        let rtl = quote.language.isRightToLeft
        Text(quote.text)
            .font(Typography.quote(rightToLeft: rtl))
            .lineSpacing(Typography.quoteLineSpacing(rightToLeft: rtl))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
            .textSelection(.enabled)
    }
}

/// AUTHOR and SOURCE columns, as on the specimen card. Empty fields are left out.
private struct Byline: View {
    let quote: Quote

    var body: some View {
        let fields = [("Author", quote.author), ("Source", quote.source)].filter { !$0.1.isEmpty }
        if !fields.isEmpty {
            VStack(spacing: 10) {
                Hairline()
                HStack(alignment: .top, spacing: 12) {
                    ForEach(fields, id: \.0) { name, value in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(text: name)
                            Text(value)
                                .font(Typography.metaValue(value))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

private struct QuoteLink: View {
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 4) {
                Label(text: "Read on goodthoughts.page", color: Theme.ink)
                    .underline(color: Theme.rule)
                Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .semibold))
            }
        }
        .foregroundStyle(Theme.ink)
        .help(url.absoluteString)
    }
}

/// The Apply button, its progress and errors, and the Spaces caveat.
private struct ApplyControls: View {
    @ObservedObject var model: AppModel
    let quote: Quote

    private var applied: Bool { model.applyState == .applied(quote.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await model.apply(quote) }
            } label: {
                HStack(spacing: 8) {
                    if model.applyState == .applying {
                        ProgressView().controlSize(.small)
                    }
                    Text(applied ? "Applied" : "Set as wallpaper")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(HighlighterButtonStyle())
            .disabled(model.applyState == .applying || quote.wallpapers.isEmpty)
            .keyboardShortcut(.defaultAction)

            if case .failed(let error) = model.applyState {
                Notice(text: error.errorDescription ?? "Couldn't set the wallpaper.")
            }
            Text("Applies to the current desktop. Other Spaces keep their wallpaper.")
                .font(Typography.meta(10))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The highlighter as a button: the one place colour appears, for the one action.
private struct HighlighterButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.label(11))
            .tracking(Typography.labelTracking(11))
            .textCase(.uppercase)
            .foregroundStyle(isEnabled ? Theme.onHighlighter : Theme.faint)
            .padding(.vertical, 9)
            .background(isEnabled ? Theme.highlighter : Theme.wash)
            .overlay(Rectangle().stroke(isEnabled ? Palette.ink : Theme.rule, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
    }
}

/// A short message with a highlighter mark in the margin. Errors stay in ink:
/// the brand has no red.
private struct Notice: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle().fill(Theme.highlighter).frame(width: 3)
            Text(text)
                .font(Typography.meta(11))
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Daily apply, the reminder and open at login, on their own page so the quote view
/// stays short.
private struct SettingsPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            group("Wallpaper")
            Toggle(isOn: Binding(get: { model.applyDaily },
                                 set: { on in Task { await model.setApplyDaily(on) } })) {
                Label(text: "Set each morning", color: Theme.ink)
            }
            .help("Sets the day's wallpaper the first time the Mac is awake each day")
            group("Notifications").padding(.top, 10)
            ReminderSettings(model: model)
            group("General").padding(.top, 10)
            Toggle(isOn: Binding(get: { model.loginItem == .enabled || model.loginItem == .requiresApproval },
                                 set: { on in model.setLaunchAtLogin(on) })) {
                Label(text: "Open at login", color: Theme.ink)
            }
            if model.applyDaily && model.loginItem == .disabled {
                hint("Turn on Open at login so the morning wallpaper still happens after a restart.")
            }
            if model.loginItem == .requiresApproval {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    hint("Allow goodthoughts in System Settings to finish.")
                    Button { model.openLoginItemsSettings() } label: {
                        Label(text: "Open", color: Theme.ink).underline(color: Theme.rule)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let error = model.loginItemError {
                Notice(text: "Couldn't change Open at login: \(error)")
            }
        }
        .toggleStyle(.checkbox)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PopoverView.gutter)
    }

    private func group(_ title: String) -> some View {
        Label(text: title, color: Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(Typography.meta(10))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The reminder: on or off, its time, how often it repeats, and what to do if
/// notifications aren't allowed.
private struct ReminderSettings: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Toggle(isOn: Binding(get: { model.reminderEnabled },
                                     set: { on in Task { await model.setReminderEnabled(on) } })) {
                    Label(text: "Reminder", color: Theme.ink)
                }
                .help("A notification with the day's quote")
                if model.reminderEnabled {
                    DatePicker("Reminder time", selection: time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .font(Typography.meta(11))
                        .fixedSize()
                }
            }
            if model.reminderEnabled {
                HStack(spacing: 6) {
                    Picker("Repeat", selection: every) {
                        ForEach(ReminderRepeat.choices, id: \.self) { hours in
                            Text(Self.everyLabel(hours)).tag(hours)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .help("Send another quote every few hours")
                    if !model.reminderRepeat.isOnce {
                        Label(text: "until", color: Theme.muted)
                        Picker("Until", selection: until) {
                            ForEach(model.reminderTime.hour...23, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                        .help("No reminders after this time")
                    }
                }
                .font(Typography.meta(11))
                switch model.reminderAuthorization {
                case .denied:
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        hint("Notifications are off for goodthoughts.")
                        Button { model.openNotificationSettings() } label: {
                            Label(text: "Settings", color: Theme.ink).underline(color: Theme.rule)
                        }
                        .buttonStyle(.plain)
                        .help("Open System Settings › Notifications")
                    }
                case .notDetermined:
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        hint("goodthoughts needs permission to notify you.")
                        Button { Task { await model.requestReminderPermission() } } label: {
                            Label(text: "Allow", color: Theme.ink).underline(color: Theme.rule)
                        }
                        .buttonStyle(.plain)
                    }
                case .authorized:
                    EmptyView()
                }
                if let error = model.reminderError {
                    Notice(text: "macOS wouldn't allow notifications: \(error)")
                }
            }
        }
    }

    static func everyLabel(_ hours: Int) -> String {
        switch hours {
        case 0: "Once a day"
        case 1: "Every hour"
        default: "Every \(hours) hours"
        }
    }

    private var every: Binding<Int> {
        Binding(
            get: { model.reminderRepeat.everyHours },
            set: { hours in
                Task { await model.setReminderRepeat(ReminderRepeat(everyHours: hours, untilHour: model.reminderRepeat.untilHour)) }
            }
        )
    }

    /// Clamped to the first reminder's hour, so the menu always has the value it shows.
    private var until: Binding<Int> {
        Binding(
            get: { max(model.reminderRepeat.untilHour, model.reminderTime.hour) },
            set: { hour in
                Task { await model.setReminderRepeat(ReminderRepeat(everyHours: model.reminderRepeat.everyHours, untilHour: hour)) }
            }
        )
    }

    /// The reminder time as a Date today, for the picker.
    private var time: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                return calendar.date(bySettingHour: model.reminderTime.hour, minute: model.reminderTime.minute,
                                     second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                let time = ReminderTime(hour: parts.hour ?? 9, minute: parts.minute ?? 0)
                Task { await model.setReminderTime(time) }
            }
        )
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(Typography.meta(10))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct Footer: View {
    let status: String
    @ObservedObject var updater: Updater

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack {
                Text(status)
                    .font(Typography.meta(10))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Spacer()
                if updater.isAvailable {
                    Button { updater.checkForUpdates() } label: { Label(text: "Updates", color: Theme.ink) }
                        .buttonStyle(.plain)
                        .disabled(!updater.canCheck)
                        .help("Check for a newer version")
                        .padding(.trailing, 12)
                }
                Button { NSApplication.shared.terminate(nil) } label: { Label(text: "Quit", color: Theme.ink) }
                    .buttonStyle(.plain)
                    .keyboardShortcut("q")
            }
            .padding(.horizontal, PopoverView.gutter)
            .padding(.vertical, 10)
        }
    }
}
