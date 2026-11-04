import SwiftUI

@main
struct GoodThoughtsApp: App {
    var body: some Scene {
        // Round 1 only proves the target builds and launches.
        // The menu bar extra arrives in round 2.
        Settings {
            Text("goodthoughts")
                .padding()
        }
    }
}
