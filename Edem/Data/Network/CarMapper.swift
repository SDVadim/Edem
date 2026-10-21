import Foundation

/// Превращает модель из каталога DummyJSON в несколько машин автопарка.
///
/// API отдаёт только модели (5 штук), а в каршеринге одна модель стоит в разных
/// точках города. Номер, топливо, координаты и чистота выводятся детерминированно
/// из id модели, поэтому между запусками машины не «прыгают» по карте.
struct CarMapper: Sendable {
    var unitsPerModel: Int = 3
    var cityCenter = Coordinate(latitude: 55.7558, longitude: 37.6173)
    /// Разброс от центра в градусах (~3 км).
    var spread = (latitude: 0.03, longitude: 0.05)

    private static let plateLetters = Array("АВЕКМНОРСТУХ")

    func map(_ products: [ProductDTO]) -> [Car] {
        products.flatMap(map)
    }

    func map(_ product: ProductDTO) -> [Car] {
        (0..<unitsPerModel).map { unit in
            var random = SeededGenerator(seed: UInt64(product.id * 100 + unit + 1))
            let latitude = cityCenter.latitude + random.nextSigned() * spread.latitude
            let longitude = cityCenter.longitude + random.nextSigned() * spread.longitude
            let fuel = 20 + Int(random.nextUnit() * 80)
            // Рейтинг из API — 2.5…4.1, приводим к шкале чистоты 3.5…5.
            let rawCleanliness = min(5, 3.5 + (product.rating - 2.5) * 0.9 + random.nextUnit() * 0.3)
            let cleanliness = (rawCleanliness * 10).rounded() / 10

            return Car(
                id: "\(product.id)-\(unit + 1)",
                modelID: product.id,
                name: product.title,
                brand: product.brand ?? "",
                summary: product.description,
                thumbnailURL: URL(string: product.thumbnail),
                imageURLs: product.images.compactMap(URL.init(string:)),
                pricePerMinute: Self.pricePerMinute(for: product.price),
                cleanliness: cleanliness,
                fuelLevel: fuel,
                plate: plate(using: &random),
                carClass: Self.carClass(for: product.price),
                coordinate: Coordinate(latitude: latitude, longitude: longitude)
            )
        }
    }

    /// Цена авто в долларах → поминутный тариф в рублях (24 999 $ → 12 ₽/мин).
    static func pricePerMinute(for price: Double) -> Int {
        max(7, Int(price / 2000))
    }

    static func carClass(for price: Double) -> CarClass {
        switch price {
        case ..<28_000: return .economy
        case ..<34_000: return .comfort
        default: return .business
        }
    }

    private func plate(using random: inout SeededGenerator) -> String {
        func letter() -> Character {
            Self.plateLetters[Int(random.nextUnit() * Double(Self.plateLetters.count)) % Self.plateLetters.count]
        }
        let digits = 100 + Int(random.nextUnit() * 899)
        let region = [77, 97, 99, 177, 197, 777, 799][Int(random.nextUnit() * 7) % 7]
        return "\(letter()) \(digits) \(letter())\(letter()) \(region)"
    }
}

/// Простой детерминированный генератор (SplitMix64).
struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0..<1
    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// -1..<1
    mutating func nextSigned() -> Double {
        nextUnit() * 2 - 1
    }
}
