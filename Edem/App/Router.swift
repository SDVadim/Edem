import SwiftUI
import Observation

enum Route: Hashable {
    case car(Car)
    case pickupInspection(Car)
    case activeRental
    case trip(UUID)
}

/// Навигационный стек одной вкладки.
@MainActor
@Observable
final class Router {
    var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    func popToRoot() {
        path.removeAll()
    }

    /// Заменяет весь стек — например, после старта аренды экран осмотра не должен остаться в истории.
    func replace(with routes: [Route]) {
        path = routes
    }
}

/// Все переходы приложения в одном месте.
struct RouteDestinations: ViewModifier {
    let container: AppContainer

    func body(content: Content) -> some View {
        content.navigationDestination(for: Route.self) { route in
            switch route {
            case .car(let car):
                CarDetailView(viewModel: container.makeCarDetailViewModel(car: car))
            case .pickupInspection(let car):
                PickupInspectionScreen(viewModel: container.makePickupViewModel(car: car))
            case .activeRental:
                ActiveRentalView(viewModel: container.makeActiveRentalViewModel(), container: container)
            case .trip(let id):
                TripDetailView(viewModel: container.makeTripDetailViewModel(tripID: id), container: container)
            }
        }
    }
}

extension View {
    func withRouteDestinations(_ container: AppContainer) -> some View {
        modifier(RouteDestinations(container: container))
    }
}
