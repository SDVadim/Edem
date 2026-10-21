import Foundation
import Observation

@MainActor
@Observable
final class MapViewModel {
    private(set) var cars: [Car] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var selectedCarID: String?

    @ObservationIgnored private let repository: CarRepository
    @ObservationIgnored private let rental: RentalSession
    @ObservationIgnored private let tariff: TariffCalculator
    @ObservationIgnored private var hasLoaded = false

    init(repository: CarRepository, rental: RentalSession, tariff: TariffCalculator) {
        self.repository = repository
        self.rental = rental
        self.tariff = tariff
    }

    var selectedCar: Car? {
        cars.first { $0.id == selectedCarID }
    }

    var activeTrip: Trip? {
        rental.currentTrip
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
                ? "Не удалось загрузить машины. Проверьте интернет."
                : "Нет сети — показаны сохранённые машины"
        }
    }

    func select(_ car: Car?) {
        selectedCarID = car?.id
    }

    func liveCost(of trip: Trip, at date: Date) -> Int {
        tariff.rideCost(pricePerMinute: trip.pricePerMinute, from: trip.startedAt, to: date)
    }
}
