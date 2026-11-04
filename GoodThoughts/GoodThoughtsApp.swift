import SwiftUI

@main
struct GoodThoughtsApp: App {
    var body: some Scene {
        MenuBarExtra {
            PopoverView()
        } label: {
            Image(nsImage: MenuBarIcon.image)
                .accessibilityLabel("goodthoughts")
        }
        .menuBarExtraStyle(.window)
    }
}
