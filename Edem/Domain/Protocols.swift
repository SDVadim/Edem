import Foundation

// Контракты слоя данных. Экраны и ViewModel знают только эти протоколы (DIP),
// конкретные реализации (сеть, SwiftData, UserDefaults) подставляются в AppContainer.

/// Источник автомобилей на сервере.
protocol CarsRemoteDataSource: Sendable {
    func fetchCars() async throws -> [Car]
}

/// Локальный кэш автомобилей — чтобы карта и каталог работали без сети.
@MainActor
protocol CarsCache: AnyObject {
    func loadCars() -> [Car]
    func replaceCars(with cars: [Car])
}

/// Единая точка получения машин для ViewModel: сеть + кэш.
@MainActor
protocol CarRepository: AnyObject {
    func cachedCars() -> [Car]
    func refreshCars() async throws -> [Car]
}

@MainActor
protocol TripRepository: AnyObject {
    /// Незавершённая поездка (active или closing), если есть.
    func currentTrip() -> Trip?
    func finishedTrips() -> [Trip]
    func trip(id: UUID) -> Trip?
    func save(_ trip: Trip)
    func deleteTrip(id: UUID)
}

struct FinishRentalRequest: Sendable, Equatable {
    let tripID: UUID
    let carID: String
    let plate: String
    let billingStoppedAt: Date
    let total: Int
}

struct FinishRentalResponse: Sendable, Equatable {
    let receiptID: Int
}

enum VehicleCommandError: LocalizedError, Equatable {
    case noConnection
    case server(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "Нет связи с автомобилем"
        case .server(let code):
            return "Сервер ответил ошибкой \(code)"
        }
    }
}

/// Команды автомобилю через сервер каршеринга.
protocol VehicleCommandService: Sendable {
    func lockAndFinish(_ request: FinishRentalRequest) async throws -> FinishRentalResponse
}

protocol SupportService: Sendable {
    /// Отправляет сообщение пользователя и возвращает его в виде, подтверждённом сервером.
    func send(text: String, topic: SupportTopic) async throws -> SupportMessage
    /// Ответ оператора на обращение. Для `.carNotLocking` оператор закрывает машину удалённо.
    func operatorReply(for topic: SupportTopic) async throws -> SupportMessage
}

protocol NotificationService: Sendable {
    func requestAuthorization() async
    func notifyRentalFinished(total: Int) async
}

@MainActor
protocol SettingsStore: AnyObject {
    var userName: String { get set }
    var email: String { get set }
    /// Демо-режим: имитировать отсутствие связи с машиной (подземный паркинг из ветки ошибки).
    var simulateNoConnection: Bool { get set }
}

/// Общая для всех вкладок текущая аренда.
@MainActor
protocol RentalSession: AnyObject {
    var currentTrip: Trip? { get }
    @discardableResult
    func startRental(car: Car, pickupPhotos: [InspectionPhoto]) -> Trip
    func update(_ trip: Trip)
    /// Убирает поездку из текущей: после «Готово» на чеке.
    func clearCurrentTrip()
}
