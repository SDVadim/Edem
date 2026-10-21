import SwiftUI
import SwiftData

@main
struct EdemApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .preferredColorScheme(.light)
        }
        .modelContainer(container.modelContainer)
    }
}
