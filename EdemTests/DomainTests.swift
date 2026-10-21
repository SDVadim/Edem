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

final class CarMapperTests: XCTestCase {
    private let product = ProductDTO(
        id: 169,
        title: "Dodge Hornet GT Plus",
        description: "Compact SUV",
        price: 24999.99,
        rating: 2.65,
        brand: "Dodge",
        thumbnail: "https://cdn.dummyjson.com/thumb.webp",
        images: ["https://cdn.dummyjson.com/1.webp", "https://cdn.dummyjson.com/2.webp"]
    )

    func testCreatesSeveralUnitsPerModel() {
        let cars = CarMapper(unitsPerModel: 3).map(product)
        XCTAssertEqual(cars.count, 3)
        XCTAssertEqual(Set(cars.map(\.id)).count, 3)
        XCTAssertTrue(cars.allSatisfy { $0.modelID == 169 && $0.name == "Dodge Hornet GT Plus" })
    }

    func testMappingIsDeterministic() {
        XCTAssertEqual(CarMapper().map(product), CarMapper().map(product))
    }

    func testTariffAndClass() {
        let car = CarMapper().map(product)[0]
        XCTAssertEqual(car.pricePerMinute, 12)
        XCTAssertEqual(car.carClass, .economy)
        XCTAssertEqual(CarMapper.carClass(for: 36_999), .business)
        XCTAssertEqual(car.imageURLs.count, 2)
    }

    func testGeneratedValuesStayInRange() {
        for car in CarMapper(unitsPerModel: 10).map(product) {
            XCTAssertTrue((20...100).contains(car.fuelLevel))
            XCTAssertTrue((0...5).contains(car.cleanliness))
            XCTAssertLessThan(abs(car.coordinate.latitude - 55.7558), 0.031)
        }
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
    func testDecodesVehicleList() async throws {
        let json = """
        {"products":[{"id":167,"title":"300 Touring","description":"Sedan","price":28999.99,"rating":4.05,
        "brand":"Chrysler","thumbnail":"https://x/t.webp","images":["https://x/1.webp"]}],"total":1}
        """
        let source = DummyJSONCarsDataSource(api: JSONAPIClient(http: StubHTTPClient(body: json)))
        let cars = try await source.fetchCars()
        XCTAssertEqual(cars.count, 3)
        XCTAssertEqual(cars.first?.pricePerMinute, 14)
    }

    func testBadStatusThrows() async {
        let source = DummyJSONCarsDataSource(api: JSONAPIClient(http: StubHTTPClient(body: "{}", status: 500)))
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
