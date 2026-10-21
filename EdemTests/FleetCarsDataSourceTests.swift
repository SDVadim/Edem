import XCTest
@testable import Edem

final class FleetCarsDataSourceTests: XCTestCase {
    func testDecodesCarWithLocationFuelAndPlate() async throws {
        let json = """
        {"cars":[{"id":"167-1","modelId":167,"title":"300 Touring","brand":"Chrysler",
        "description":"Sedan","pricePerMinute":14,"carClass":"comfort","plate":"А 123 ВС 77",
        "fuelLevel":64,"cleanliness":4.6,"latitude":55.7601,"longitude":37.6012,
        "thumbnail":"https://x/t.webp","images":["https://x/1.webp","https://x/2.webp"]}]}
        """
        let source = FleetCarsDataSource(api: JSONAPIClient(http: StubHTTPClient(body: json)))
        let cars = try await source.fetchCars()

        XCTAssertEqual(cars.count, 1)
        let car = try XCTUnwrap(cars.first)
        XCTAssertEqual(car.id, "167-1")
        XCTAssertEqual(car.modelID, 167)
        XCTAssertEqual(car.name, "300 Touring")
        XCTAssertEqual(car.pricePerMinute, 14)
        XCTAssertEqual(car.carClass, .comfort)
        XCTAssertEqual(car.plate, "А 123 ВС 77")
        XCTAssertEqual(car.fuelLevel, 64)
        XCTAssertEqual(car.cleanliness, 4.6)
        XCTAssertEqual(car.coordinate, Coordinate(latitude: 55.7601, longitude: 37.6012))
        XCTAssertEqual(car.imageURLs.count, 2)
    }

    func testMissingBrandBecomesEmptyString() {
        let dto = FleetCarDTO(
            id: "1-1", modelId: 1, title: "Car", brand: nil, description: "",
            pricePerMinute: 10, carClass: .economy, plate: "А 100 АА 77",
            fuelLevel: 50, cleanliness: 4, latitude: 55.75, longitude: 37.61,
            thumbnail: "https://x/t.webp", images: []
        )
        XCTAssertEqual(FleetCarsDataSource.car(from: dto).brand, "")
    }

    func testUnknownCarClassIsRejected() async {
        let json = """
        {"cars":[{"id":"1-1","modelId":1,"title":"Car","brand":null,"description":"",
        "pricePerMinute":10,"carClass":"premium","plate":"А 100 АА 77","fuelLevel":50,
        "cleanliness":4,"latitude":55.75,"longitude":37.61,"thumbnail":"https://x/t.webp","images":[]}]}
        """
        let source = FleetCarsDataSource(api: JSONAPIClient(http: StubHTTPClient(body: json)))
        do {
            _ = try await source.fetchCars()
            XCTFail("Неизвестный класс машины должен давать ошибку, а не подменяться")
        } catch NetworkError.decoding(_) {
            // Ожидаемо: данные сервера не «додумываются» в приложении.
        } catch {
            XCTFail("Неожиданная ошибка \(error)")
        }
    }
}
