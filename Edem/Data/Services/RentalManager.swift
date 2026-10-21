import Foundation
import Observation

/// Текущая аренда, общая для всех вкладок. Хранит состояние в памяти для UI
/// и сохраняет каждое изменение через TripRepository.
@MainActor
@Observable
final class RentalManager: RentalSession {
    private(set) var currentTrip: Trip?

    @ObservationIgnored private let repository: TripRepository
    @ObservationIgnored private let now: () -> Date

    init(repository: TripRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
        currentTrip = repository.currentTrip()
    }

    @discardableResult
    func startRental(car: Car, pickupPhotos: [InspectionPhoto]) -> Trip {
        let trip = Trip(
            carID: car.id,
            carName: car.name,
            plate: car.plate,
            thumbnailURL: car.thumbnailURL,
            pricePerMinute: car.pricePerMinute,
            startedAt: now(),
            photos: pickupPhotos
        )
        repository.save(trip)
        currentTrip = trip
        return trip
    }

    func update(_ trip: Trip) {
        repository.save(trip)
        if currentTrip?.id == trip.id || currentTrip == nil {
            currentTrip = trip
        }
    }

    func clearCurrentTrip() {
        currentTrip = nil
    }
}
