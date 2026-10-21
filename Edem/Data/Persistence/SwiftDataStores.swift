import Foundation
import SwiftData

@MainActor
final class SwiftDataCarsCache: CarsCache {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadCars() -> [Car] {
        let descriptor = FetchDescriptor<CarEntity>(sortBy: [SortDescriptor(\.sortIndex)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.domain)
    }

    func replaceCars(with cars: [Car]) {
        do {
            try context.delete(model: CarEntity.self)
            for (index, car) in cars.enumerated() {
                context.insert(CarEntity(car: car, sortIndex: index))
            }
            try context.save()
        } catch {
            print("SwiftDataCarsCache: не удалось сохранить кэш — \(error)")
        }
    }
}

@MainActor
final class SwiftDataTripRepository: TripRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func currentTrip() -> Trip? {
        let finished = TripStatus.finished.rawValue
        var descriptor = FetchDescriptor<TripEntity>(
            predicate: #Predicate { $0.statusRaw != finished },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.domain
    }

    func finishedTrips() -> [Trip] {
        let finished = TripStatus.finished.rawValue
        let descriptor = FetchDescriptor<TripEntity>(
            predicate: #Predicate { $0.statusRaw == finished },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map(\.domain)
    }

    func trip(id: UUID) -> Trip? {
        entity(id: id)?.domain
    }

    func save(_ trip: Trip) {
        let entity: TripEntity
        if let existing = self.entity(id: trip.id) {
            existing.apply(trip)
            entity = existing
        } else {
            entity = TripEntity(trip: trip)
            context.insert(entity)
        }
        // Фото только добавляются: акт осмотра нельзя переписать задним числом.
        let storedIDs = Set(entity.photos.map(\.id))
        for photo in trip.photos where !storedIDs.contains(photo.id) {
            let photoEntity = InspectionPhotoEntity(photo: photo)
            context.insert(photoEntity)
            photoEntity.trip = entity
        }
        persist()
    }

    func deleteTrip(id: UUID) {
        guard let entity = entity(id: id) else { return }
        context.delete(entity)
        persist()
    }

    private func entity(id: UUID) -> TripEntity? {
        var descriptor = FetchDescriptor<TripEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func persist() {
        do {
            try context.save()
        } catch {
            print("SwiftDataTripRepository: ошибка сохранения — \(error)")
        }
    }
}
