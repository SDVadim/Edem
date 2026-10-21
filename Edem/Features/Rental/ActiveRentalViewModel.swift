import Foundation
import Observation

@MainActor
@Observable
final class ActiveRentalViewModel {
    private(set) var doorsLocked = false
    private(set) var lockMessage: String?

    @ObservationIgnored private let rental: RentalSession
    @ObservationIgnored private let repository: CarRepository
    @ObservationIgnored private let tariff: TariffCalculator

    init(rental: RentalSession, repository: CarRepository, tariff: TariffCalculator) {
        self.rental = rental
        self.repository = repository
        self.tariff = tariff
    }

    var trip: Trip? { rental.currentTrip }

    var car: Car? {
        guard let trip else { return nil }
        return repository.cachedCars().first { $0.id == trip.carID }
    }

    /// Завершение было начато, но машина так и не подтвердила закрытие (например, приложение закрыли).
    var isClosingPending: Bool {
        trip?.status == .closing
    }

    func elapsedText(at date: Date) -> String {
        guard let trip else { return "" }
        return Formatters.duration((trip.billingStoppedAt ?? date).timeIntervalSince(trip.startedAt))
    }

    func cost(at date: Date) -> Int {
        guard let trip else { return 0 }
        return tariff.rideCost(pricePerMinute: trip.pricePerMinute, from: trip.startedAt, to: trip.billingStoppedAt ?? date)
    }

    func setDoorsLocked(_ locked: Bool) {
        doorsLocked = locked
        lockMessage = locked ? "Двери закрыты" : "Двери открыты"
    }
}
