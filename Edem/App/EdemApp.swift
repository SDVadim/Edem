import SwiftUI
import SwiftData

@main
struct EdemApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                // Макет нарисован только в светлой теме.
                .preferredColorScheme(.light)
        }
        .modelContainer(container.modelContainer)
    }
}
