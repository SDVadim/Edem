import Foundation

/// Offline-first: сначала отдаём кэш, затем обновляем его из сети.
@MainActor
final class DefaultCarRepository: CarRepository {
    private let remote: CarsRemoteDataSource
    private let cache: CarsCache

    init(remote: CarsRemoteDataSource, cache: CarsCache) {
        self.remote = remote
        self.cache = cache
    }

    func cachedCars() -> [Car] {
        cache.loadCars()
    }

    func refreshCars() async throws -> [Car] {
        let cars = try await remote.fetchCars()
        cache.replaceCars(with: cars)
        return cars
    }
}
