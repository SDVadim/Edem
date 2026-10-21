import SwiftUI

enum AppTab: Hashable {
    case map
    case catalog
    case trips
    case profile
}

struct RootView: View {
    let container: AppContainer

    @State private var selection: AppTab = .map
    @State private var mapRouter = Router()
    @State private var catalogRouter = Router()
    @State private var tripsRouter = Router()
    @State private var profileRouter = Router()

    @State private var mapViewModel: MapViewModel
    @State private var catalogViewModel: CatalogViewModel
    @State private var tripsViewModel: TripsViewModel
    @State private var profileViewModel: ProfileViewModel

    init(container: AppContainer) {
        self.container = container
        _mapViewModel = State(initialValue: container.makeMapViewModel())
        _catalogViewModel = State(initialValue: container.makeCatalogViewModel())
        _tripsViewModel = State(initialValue: container.makeTripsViewModel())
        _profileViewModel = State(initialValue: container.makeProfileViewModel())
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $mapRouter.path) {
                MapScreen(viewModel: mapViewModel)
                    .withRouteDestinations(container)
            }
            .environment(mapRouter)
            .tabItem { Label("Карта", systemImage: "map") }
            .tag(AppTab.map)

            NavigationStack(path: $catalogRouter.path) {
                CatalogScreen(viewModel: catalogViewModel, imageLoader: container.imageLoader)
                    .withRouteDestinations(container)
            }
            .environment(catalogRouter)
            .tabItem { Label("Автомобили", systemImage: "car.2") }
            .tag(AppTab.catalog)

            NavigationStack(path: $tripsRouter.path) {
                TripsView(viewModel: tripsViewModel)
                    .withRouteDestinations(container)
            }
            .environment(tripsRouter)
            .tabItem { Label("Поездки", systemImage: "clock.arrow.circlepath") }
            .tag(AppTab.trips)

            NavigationStack(path: $profileRouter.path) {
                ProfileView(viewModel: profileViewModel)
                    .withRouteDestinations(container)
            }
            .environment(profileRouter)
            .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .tint(Palette.accent)
        .task { await container.requestNotificationPermission() }
    }
}
