import XCTest
@testable import Edem

@MainActor
final class CatalogViewModelTests: XCTestCase {
    func testFiltersByClassAndFuel() async {
        let repository = MockCarRepository(cars: [
            .stub(id: "1", carClass: .economy, fuel: 80),
            .stub(id: "2", carClass: .business, fuel: 30),
            .stub(id: "3", carClass: .economy, fuel: 55),
        ])
        let viewModel = CatalogViewModel(repository: repository)
        await viewModel.loadIfNeeded()

        viewModel.filter = .economy
        XCTAssertEqual(viewModel.visibleCars.map(\.id), ["1", "3"])

        viewModel.filter = .fullTank
        XCTAssertEqual(viewModel.visibleCars.map(\.id), ["1", "3"])

        viewModel.filter = .business
        XCTAssertEqual(viewModel.visibleCars.map(\.id), ["2"])
    }

    func testShowsCacheWhenNetworkFails() async {
        let repository = MockCarRepository(cars: [.stub(id: "1")])
        repository.refreshError = URLError(.notConnectedToInternet)
        let viewModel = CatalogViewModel(repository: repository)
        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.visibleCars.count, 1)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}

@MainActor
final class FinishFlowViewModelTests: XCTestCase {
    private var clock = Date(timeIntervalSince1970: 1_000_000)

    func testHappyPathStopsBillingAndProducesReceipt() async throws {
        let rental = MockRentalSession()
        let vehicle = MockVehicleService(result: .success(FinishRentalResponse(receiptID: 252)))
        let notifications = MockNotificationService()
        let flow = makeFlow(rental: rental, vehicle: vehicle, notifications: notifications)

        flow.checklist.forEach(flow.toggle)
        XCTAssertTrue(flow.isChecklistComplete)
        flow.proceedFromChecklist()
        flow.proceedFromZone()
        fillPhotos(flow.inspection)

        clock = clock.addingTimeInterval(42 * 60)
        flow.requestFinish()
        XCTAssertTrue(flow.isConfirmPresented)
        XCTAssertEqual(flow.expectedTotal, 42 * 16 + 12)

        flow.confirmFinish()
        XCTAssertEqual(rental.updates.first?.status, .closing)
        XCTAssertNotNil(rental.updates.first?.billingStoppedAt)

        try await waitUntil { flow.closingState == .done }
        XCTAssertEqual(flow.path.last, .receipt)
        XCTAssertEqual(flow.trip.status, .finished)
        XCTAssertEqual(flow.trip.serverReceiptID, 252)
        XCTAssertEqual(flow.receipt?.total, 684)
        XCTAssertEqual(flow.trip.photos(for: .dropoff).count, 4)
        try await waitUntil { notifications.notifiedTotals == [684] }
    }

    func testConnectionFailureThenOperatorResolution() async throws {
        let rental = MockRentalSession()
        let vehicle = MockVehicleService(result: .failure(VehicleCommandError.noConnection))
        let flow = makeFlow(rental: rental, vehicle: vehicle, notifications: MockNotificationService())
        fillPhotos(flow.inspection)
        flow.confirmFinish()

        try await waitUntil {
            if case .failed(attempt: 1, _) = flow.closingState { return true }
            return false
        }

        flow.retry()
        try await waitUntil {
            if case .failed(attempt: 2, _) = flow.closingState { return true }
            return false
        }

        flow.openSupport()
        XCTAssertEqual(flow.path.last, .support)

        clock = clock.addingTimeInterval(4 * 60)
        await flow.supportResolved()
        XCTAssertTrue(flow.trip.closedByOperator)
        XCTAssertEqual(flow.receipt?.waitingMinutes, 4)
        XCTAssertEqual(flow.path.last, .receipt)
    }

    // MARK: - Helpers

    private func makeFlow(
        rental: MockRentalSession,
        vehicle: MockVehicleService,
        notifications: MockNotificationService
    ) -> FinishFlowViewModel {
        let trip = Trip(carID: "1", carName: "Car", plate: "А 1 АА 77", thumbnailURL: nil, pricePerMinute: 16, startedAt: clock)
        rental.currentTrip = trip
        return FinishFlowViewModel(
            trip: trip,
            car: .stub(id: "1"),
            rental: rental,
            vehicleService: vehicle,
            notifications: notifications,
            tariff: TariffCalculator(),
            inspection: InspectionViewModel(stage: .dropoff),
            resumeClosing: false,
            now: { [unowned self] in self.clock }
        )
    }

    private func fillPhotos(_ inspection: InspectionViewModel) {
        for side in CarSide.allCases {
            inspection.addPhoto(Data([0x1]), for: side)
        }
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Условие не выполнилось за \(timeout) с")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

// MARK: - Моки

extension Car {
    static func stub(id: String, carClass: CarClass = .comfort, fuel: Int = 70) -> Car {
        Car(
            id: id,
            modelID: 1,
            name: "Car \(id)",
            brand: "Brand",
            summary: "",
            thumbnailURL: nil,
            imageURLs: [],
            pricePerMinute: 16,
            cleanliness: 4.5,
            fuelLevel: fuel,
            plate: "А 1 АА 77",
            carClass: carClass,
            coordinate: Coordinate(latitude: 55.75, longitude: 37.61)
        )
    }
}

@MainActor
final class MockCarRepository: CarRepository {
    var cars: [Car]
    var refreshError: Error?

    init(cars: [Car]) {
        self.cars = cars
    }

    func cachedCars() -> [Car] { cars }

    func refreshCars() async throws -> [Car] {
        if let refreshError { throw refreshError }
        return cars
    }
}

@MainActor
final class MockRentalSession: RentalSession {
    var currentTrip: Trip?
    private(set) var updates: [Trip] = []

    func startRental(car: Car, pickupPhotos: [InspectionPhoto]) -> Trip {
        let trip = Trip(carID: car.id, carName: car.name, plate: car.plate, thumbnailURL: nil, pricePerMinute: car.pricePerMinute, startedAt: Date())
        currentTrip = trip
        return trip
    }

    func update(_ trip: Trip) {
        updates.append(trip)
        currentTrip = trip
    }

    func clearCurrentTrip() {
        currentTrip = nil
    }
}

struct MockVehicleService: VehicleCommandService {
    let result: Result<FinishRentalResponse, Error>

    func lockAndFinish(_ request: FinishRentalRequest) async throws -> FinishRentalResponse {
        try result.get()
    }
}

final class MockNotificationService: NotificationService, @unchecked Sendable {
    private(set) var notifiedTotals: [Int] = []

    func requestAuthorization() async {}

    func notifyRentalFinished(total: Int) async {
        notifiedTotals.append(total)
    }
}
