import Foundation
import SwiftData

// Модели хранения SwiftData. Наружу из слоя данных они не выходят:
// репозитории конвертируют их в доменные структуры Car / Trip.

@Model
final class CarEntity {
    @Attribute(.unique) var id: String
    var modelID: Int
    var name: String
    var brand: String
    var summary: String
    var thumbnailURL: String?
    var imageURLs: [String]
    var pricePerMinute: Int
    var cleanliness: Double
    var fuelLevel: Int
    var plate: String
    var carClassRaw: String
    var latitude: Double
    var longitude: Double
    var sortIndex: Int

    init(car: Car, sortIndex: Int) {
        id = car.id
        modelID = car.modelID
        name = car.name
        brand = car.brand
        summary = car.summary
        thumbnailURL = car.thumbnailURL?.absoluteString
        imageURLs = car.imageURLs.map(\.absoluteString)
        pricePerMinute = car.pricePerMinute
        cleanliness = car.cleanliness
        fuelLevel = car.fuelLevel
        plate = car.plate
        carClassRaw = car.carClass.rawValue
        latitude = car.coordinate.latitude
        longitude = car.coordinate.longitude
        self.sortIndex = sortIndex
    }

    var domain: Car {
        Car(
            id: id,
            modelID: modelID,
            name: name,
            brand: brand,
            summary: summary,
            thumbnailURL: thumbnailURL.flatMap(URL.init(string:)),
            imageURLs: imageURLs.compactMap(URL.init(string:)),
            pricePerMinute: pricePerMinute,
            cleanliness: cleanliness,
            fuelLevel: fuelLevel,
            plate: plate,
            carClass: CarClass(rawValue: carClassRaw) ?? .comfort,
            coordinate: Coordinate(latitude: latitude, longitude: longitude)
        )
    }
}

@Model
final class TripEntity {
    @Attribute(.unique) var id: UUID
    var carID: String
    var carName: String
    var plate: String
    var thumbnailURL: String?
    var pricePerMinute: Int
    var startedAt: Date
    var statusRaw: String
    var billingStoppedAt: Date?
    var closedAt: Date?
    var receiptData: Data?
    var serverReceiptID: Int?
    var closedByOperator: Bool
    @Relationship(deleteRule: .cascade, inverse: \InspectionPhotoEntity.trip)
    var photos: [InspectionPhotoEntity] = []

    init(trip: Trip) {
        id = trip.id
        carID = trip.carID
        carName = trip.carName
        plate = trip.plate
        thumbnailURL = trip.thumbnailURL?.absoluteString
        pricePerMinute = trip.pricePerMinute
        startedAt = trip.startedAt
        statusRaw = trip.status.rawValue
        closedByOperator = trip.closedByOperator
        apply(trip)
    }

    /// Переносит изменяемые поля из доменной модели.
    func apply(_ trip: Trip) {
        statusRaw = trip.status.rawValue
        billingStoppedAt = trip.billingStoppedAt
        closedAt = trip.closedAt
        receiptData = trip.receipt.flatMap { try? JSONEncoder().encode($0) }
        serverReceiptID = trip.serverReceiptID
        closedByOperator = trip.closedByOperator
    }

    var domain: Trip {
        Trip(
            id: id,
            carID: carID,
            carName: carName,
            plate: plate,
            thumbnailURL: thumbnailURL.flatMap(URL.init(string:)),
            pricePerMinute: pricePerMinute,
            startedAt: startedAt,
            status: TripStatus(rawValue: statusRaw) ?? .finished,
            billingStoppedAt: billingStoppedAt,
            closedAt: closedAt,
            receipt: receiptData.flatMap { try? JSONDecoder().decode(Receipt.self, from: $0) },
            serverReceiptID: serverReceiptID,
            closedByOperator: closedByOperator,
            photos: photos.map(\.domain)
        )
    }
}

@Model
final class InspectionPhotoEntity {
    @Attribute(.unique) var id: UUID
    var sideRaw: String
    var stageRaw: String
    @Attribute(.externalStorage) var imageData: Data
    var takenAt: Date
    var trip: TripEntity?

    init(photo: InspectionPhoto) {
        id = photo.id
        sideRaw = photo.side.rawValue
        stageRaw = photo.stage.rawValue
        imageData = photo.imageData
        takenAt = photo.takenAt
    }

    var domain: InspectionPhoto {
        InspectionPhoto(
            id: id,
            side: CarSide(rawValue: sideRaw) ?? .front,
            stage: InspectionStage(rawValue: stageRaw) ?? .pickup,
            imageData: imageData,
            takenAt: takenAt
        )
    }
}
