import Foundation
import Observation

/// Фильтры каталога. «Полный бак» — ответ на боль из CJM «не видно уровня топлива».
enum CatalogFilter: String, CaseIterable, Hashable, Sendable {
    case all
    case economy
    case comfort
    case business
    case fullTank

    var title: String {
        switch self {
        case .all: return "Все"
        case .economy: return CarClass.economy.title
        case .comfort: return CarClass.comfort.title
        case .business: return CarClass.business.title
        case .fullTank: return "Топливо 50%+"
        }
    }
}

@MainActor
@Observable
final class CatalogViewModel {
    private(set) var cars: [Car] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var filter: CatalogFilter = .all

    @ObservationIgnored private let repository: CarRepository
    @ObservationIgnored private var hasLoaded = false

    init(repository: CarRepository) {
        self.repository = repository
    }

    var visibleCars: [Car] {
        switch filter {
        case .all:
            return cars
        case .economy:
            return cars.filter { $0.carClass == .economy }
        case .comfort:
            return cars.filter { $0.carClass == .comfort }
        case .business:
            return cars.filter { $0.carClass == .business }
        case .fullTank:
            return cars.filter { $0.fuelLevel >= 50 }.sorted { $0.fuelLevel > $1.fuelLevel }
        }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        cars = repository.cachedCars()
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            cars = try await repository.refreshCars()
            errorMessage = nil
        } catch {
            errorMessage = cars.isEmpty
                ? "Не удалось загрузить машины. Потяните вниз, чтобы повторить."
                : "Нет сети — показаны сохранённые машины"
        }
    }
}
