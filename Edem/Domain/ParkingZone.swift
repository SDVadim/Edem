import Foundation

/// Зона завершения аренды (кадр 3 стори-фрейма).
struct ParkingZone: Hashable, Sendable {
    let center: Coordinate
    /// Радиус в метрах.
    let radius: Double
    /// Подсказка о плохой связи (подземный паркинг) — вывод №3 из ветки ошибки.
    var hasWeakSignal: Bool = false

    func contains(_ point: Coordinate) -> Bool {
        Self.distance(from: center, to: point) <= radius
    }

    /// Расстояние по формуле гаверсинусов, метры.
    static func distance(from a: Coordinate, to b: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }
}
