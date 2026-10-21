import Foundation

/// Географическая точка без зависимости от CoreLocation, чтобы домен не тянул фреймворки UI/карт.
struct Coordinate: Hashable, Codable, Sendable {
    let latitude: Double
    let longitude: Double
}

enum CarClass: String, CaseIterable, Codable, Sendable {
    case economy
    case comfort
    case business

    var title: String {
        switch self {
        case .economy: return "Эконом"
        case .comfort: return "Комфорт"
        case .business: return "Бизнес"
        }
    }
}

/// Конкретный автомобиль автопарка (одна модель может быть представлена несколькими машинами).
struct Car: Identifiable, Hashable, Sendable {
    let id: String
    let modelID: Int
    let name: String
    let brand: String
    let summary: String
    let thumbnailURL: URL?
    let imageURLs: [URL]
    let pricePerMinute: Int
    /// Рейтинг чистоты салона по отзывам, 0...5.
    let cleanliness: Double
    /// Уровень топлива в процентах.
    let fuelLevel: Int
    let plate: String
    let carClass: CarClass
    let coordinate: Coordinate
}
