import Foundation
import Observation

@MainActor
@Observable
final class CarDetailViewModel {
    enum Availability: Equatable {
        case available
        /// Эта машина уже у пользователя.
        case inUseByMe
        /// У пользователя другая незавершённая аренда.
        case blockedByOtherTrip
    }

    let car: Car
    @ObservationIgnored private let rental: RentalSession

    init(car: Car, rental: RentalSession) {
        self.car = car
        self.rental = rental
    }

    var availability: Availability {
        guard let trip = rental.currentTrip else { return .available }
        return trip.carID == car.id ? .inUseByMe : .blockedByOtherTrip
    }

    var galleryURLs: [URL] {
        car.imageURLs.isEmpty ? [car.thumbnailURL].compactMap { $0 } : car.imageURLs
    }
}
