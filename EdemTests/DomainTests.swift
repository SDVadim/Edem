import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Edem

final class TariffCalculatorTests: XCTestCase {
    private let calculator = TariffCalculator()
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testLiveCostMatchesStoryFrame() {
        // Кадр 1: 00:41:18 при 16 ₽/мин → 656 ₽.
        let end = start.addingTimeInterval(41 * 60 + 18)
        XCTAssertEqual(calculator.rideCost(pricePerMinute: 16, from: start, to: end), 656)
    }

    func testMinimumOneMinute() {
        XCTAssertEqual(calculator.billableMinutes(from: start, to: start.addingTimeInterval(5)), 1)
    }

    func testReceiptIncludesInsuranceAndWaivesWaiting() {
        // Кадры 7 и 6д: 42 мин × 16 = 672 + 12 страховка = 684, ожидание 3 мин не оплачивается.
        let trip = Trip(carID: "1", carName: "Car", plate: "А 1 АА 77", thumbnailURL: nil, pricePerMinute: 16, startedAt: start)
        let stopped = start.addingTimeInterval(42 * 60 + 5)
        let closed = stopped.addingTimeInterval(3 * 60 + 10)

        let receipt = calculator.receipt(for: trip, billingStoppedAt: stopped, closedAt: closed)

        XCTAssertEqual(receipt.rideMinutes, 42)
        XCTAssertEqual(receipt.rideCost, 672)
        XCTAssertEqual(receipt.insurance, 12)
        XCTAssertEqual(receipt.waitingMinutes, 3)
        XCTAssertEqual(receipt.waivedWaitingCost, 48)
        XCTAssertEqual(receipt.total, 684)
    }
}

final class ParkingZoneTests: XCTestCase {
    func testContainsPointInsideRadius() {
        let zone = ParkingZone(center: Coordinate(latitude: 55.75, longitude: 37.61), radius: 250)
        XCTAssertTrue(zone.contains(Coordinate(latitude: 55.7510, longitude: 37.6110)))
        XCTAssertFalse(zone.contains(Coordinate(latitude: 55.76, longitude: 37.62)))
    }
}

final class JSONAPIClientTests: XCTestCase {
    func testBadStatusThrows() async {
        let source = FleetCarsDataSource(api: JSONAPIClient(http: StubHTTPClient(body: "{}", status: 500)))
        do {
            _ = try await source.fetchCars()
            XCTFail("Ожидалась ошибка")
        } catch NetworkError.badStatus(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Неожиданная ошибка \(error)")
        }
    }

    func testConnectionLossIsReported() async {
        let service = ConnectionAwareVehicleService(
            wrapped: DummyJSONVehicleCommandService(api: JSONAPIClient(http: StubHTTPClient(body: "{\"id\":1}"))),
            isConnectionLost: { true },
            simulatedFailureDelay: .milliseconds(1)
        )
        let request = FinishRentalRequest(tripID: UUID(), carID: "1", plate: "А", billingStoppedAt: Date(), total: 1)
        do {
            _ = try await service.lockAndFinish(request)
            XCTFail("Ожидалась ошибка связи")
        } catch {
            XCTAssertEqual(error as? VehicleCommandError, .noConnection)
        }
    }
}

struct StubHTTPClient: HTTPClient {
    let body: String
    var status = 200

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}
