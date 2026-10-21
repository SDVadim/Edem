import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    struct Stats: Equatable {
        var tripsCount = 0
        var totalMinutes = 0
        var totalSpent = 0
        var inspectionPhotos = 0
    }

    private(set) var stats = Stats()

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let trips: TripRepository

    init(settings: SettingsStore, trips: TripRepository) {
        self.settings = settings
        self.trips = trips
    }

    var userName: String {
        get { settings.userName }
        set { settings.userName = newValue }
    }

    var email: String {
        get { settings.email }
        set { settings.email = newValue }
    }

    var simulateNoConnection: Bool {
        get { settings.simulateNoConnection }
        set { settings.simulateNoConnection = newValue }
    }

    func reloadStats() {
        let finished = trips.finishedTrips()
        stats = Stats(
            tripsCount: finished.count,
            totalMinutes: finished.compactMap(\.receipt?.rideMinutes).reduce(0, +),
            totalSpent: finished.compactMap(\.receipt?.total).reduce(0, +),
            inspectionPhotos: finished.reduce(0) { $0 + $1.photos.count }
        )
    }
}
