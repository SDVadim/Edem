import Foundation
import Observation

@MainActor
@Observable
final class TripsViewModel {
    private(set) var trips: [Trip] = []

    @ObservationIgnored private let repository: TripRepository

    init(repository: TripRepository) {
        self.repository = repository
    }

    func reload() {
        trips = repository.finishedTrips()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            repository.deleteTrip(id: trips[index].id)
        }
        reload()
    }
}

@MainActor
@Observable
final class TripDetailViewModel {
    private(set) var trip: Trip?

    @ObservationIgnored private let tripID: UUID
    @ObservationIgnored private let repository: TripRepository

    init(tripID: UUID, repository: TripRepository) {
        self.tripID = tripID
        self.repository = repository
        trip = repository.trip(id: tripID)
    }

    var pickupPhotos: [InspectionPhoto] { trip?.photos(for: .pickup) ?? [] }
    var dropoffPhotos: [InspectionPhoto] { trip?.photos(for: .dropoff) ?? [] }

    var durationText: String {
        guard let trip, let end = trip.billingStoppedAt else { return "" }
        return Formatters.duration(end.timeIntervalSince(trip.startedAt))
    }
}
