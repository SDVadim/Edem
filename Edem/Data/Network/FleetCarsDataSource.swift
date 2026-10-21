import Foundation

enum FleetEndpoint {
    static let cars = URL(string: "https://gist.githubusercontent.com/SDVadim/c726a115d36ee59bde44e8c35e37f402/raw/cars.json")!
}

struct FleetResponseDTO: Decodable {
    let cars: [FleetCarDTO]
}

/// Машина автопарка в том виде, в каком её отдаёт сервер: со всеми полями,
/// включая координаты, топливо и госномер
struct FleetCarDTO: Decodable {
    let id: String
    let modelId: Int
    let title: String
    let brand: String?
    let description: String
    let pricePerMinute: Int
    let carClass: CarClass
    let plate: String
    let fuelLevel: Int
    let cleanliness: Double
    let latitude: Double
    let longitude: Double
    let thumbnail: String
    let images: [String]
}

/// Машины из своего cars.json.
struct FleetCarsDataSource: CarsRemoteDataSource {
    let api: JSONAPIClient
    var url: URL = FleetEndpoint.cars

    func fetchCars() async throws -> [Car] {
        let response: FleetResponseDTO = try await api.get(url)
        return response.cars.map(Self.car(from:))
    }

    static func car(from dto: FleetCarDTO) -> Car {
        Car(
            id: dto.id,
            modelID: dto.modelId,
            name: dto.title,
            brand: dto.brand ?? "",
            summary: dto.description,
            thumbnailURL: URL(string: dto.thumbnail),
            imageURLs: dto.images.compactMap(URL.init(string:)),
            pricePerMinute: dto.pricePerMinute,
            cleanliness: dto.cleanliness,
            fuelLevel: dto.fuelLevel,
            plate: dto.plate,
            carClass: dto.carClass,
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude)
        )
    }
}
