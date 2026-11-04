import SwiftUI

@main
struct GoodThoughtsApp: App {
    @StateObject private var model = AppModel()

    init() {
        BrandFont.registerAll()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            Image(nsImage: MenuBarIcon.image)
                .accessibilityLabel("goodthoughts")
                // The label exists from launch, so this loads the feed at startup.
                .task { await model.refresh() }
        }
        .menuBarExtraStyle(.window)
    }
}
