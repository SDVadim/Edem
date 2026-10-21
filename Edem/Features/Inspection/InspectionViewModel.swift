import Foundation
import Observation

/// Фотоконтроль с 4 сторон (кадр 4). Используется и при получении машины, и при завершении.
@MainActor
@Observable
final class InspectionViewModel {
    let stage: InspectionStage
    private(set) var photos: [CarSide: InspectionPhoto] = [:]

    @ObservationIgnored private let now: () -> Date

    init(stage: InspectionStage, now: @escaping () -> Date = Date.init) {
        self.stage = stage
        self.now = now
    }

    var sides: [CarSide] { CarSide.allCases }

    var completedCount: Int { photos.count }

    var progressText: String { "\(completedCount) из \(sides.count)" }

    var progress: Double { Double(completedCount) / Double(sides.count) }

    var isComplete: Bool { completedCount == sides.count }

    var nextMissingSide: CarSide? {
        sides.first { photos[$0] == nil }
    }

    var orderedPhotos: [InspectionPhoto] {
        sides.compactMap { photos[$0] }
    }

    var title: String {
        stage == .pickup ? "Осмотр перед поездкой" : "Фотоконтроль"
    }

    var subtitle: String {
        "Снимите машину с 4 сторон — это защитит вас от претензий"
    }

    func photo(for side: CarSide) -> InspectionPhoto? {
        photos[side]
    }

    func addPhoto(_ imageData: Data, for side: CarSide) {
        photos[side] = InspectionPhoto(side: side, stage: stage, imageData: imageData, takenAt: now())
    }
}

/// Осмотр перед стартом: после 4 фото начинается аренда.
@MainActor
@Observable
final class PickupViewModel {
    let car: Car
    let inspection: InspectionViewModel
    @ObservationIgnored private let rental: RentalSession

    init(car: Car, rental: RentalSession, inspection: InspectionViewModel) {
        self.car = car
        self.rental = rental
        self.inspection = inspection
    }

    var canStart: Bool {
        inspection.isComplete && rental.currentTrip == nil
    }

    func startRental() {
        guard canStart else { return }
        rental.startRental(car: car, pickupPhotos: inspection.orderedPhotos)
    }
}
