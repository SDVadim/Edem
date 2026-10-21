import Foundation

enum CarSide: String, CaseIterable, Codable, Sendable, Identifiable {
    case front
    case left
    case right
    case back

    var id: String { rawValue }

    var title: String {
        switch self {
        case .front: return "Спереди"
        case .left: return "Слева"
        case .right: return "Справа"
        case .back: return "Сзади"
        }
    }
}

enum InspectionStage: String, Codable, Sendable {
    /// Осмотр перед началом поездки.
    case pickup
    /// Фотоконтроль при завершении аренды.
    case dropoff

    var title: String {
        switch self {
        case .pickup: return "Осмотр при получении"
        case .dropoff: return "Фотоконтроль при завершении"
        }
    }
}

struct InspectionPhoto: Identifiable, Hashable, Sendable {
    let id: UUID
    let side: CarSide
    let stage: InspectionStage
    let imageData: Data
    let takenAt: Date

    init(id: UUID = UUID(), side: CarSide, stage: InspectionStage, imageData: Data, takenAt: Date) {
        self.id = id
        self.side = side
        self.stage = stage
        self.imageData = imageData
        self.takenAt = takenAt
    }
}

enum TripStatus: String, Codable, Sendable {
    /// Машина у пользователя, счёт идёт.
    case active
    /// Пользователь нажал «Завершить», счёт остановлен, ждём подтверждения от машины.
    case closing
    case finished
}

struct Trip: Identifiable, Hashable, Sendable {
    let id: UUID
    let carID: String
    let carName: String
    let plate: String
    let thumbnailURL: URL?
    let pricePerMinute: Int
    let startedAt: Date
    var status: TripStatus
    /// Момент нажатия «Завершить»: после него деньги не списываются, даже если машина отвечает долго.
    var billingStoppedAt: Date?
    /// Момент, когда машина реально закрылась (или её закрыл оператор).
    var closedAt: Date?
    var receipt: Receipt?
    /// Номер чека, выданный сервером.
    var serverReceiptID: Int?
    var closedByOperator: Bool
    var photos: [InspectionPhoto]

    init(
        id: UUID = UUID(),
        carID: String,
        carName: String,
        plate: String,
        thumbnailURL: URL?,
        pricePerMinute: Int,
        startedAt: Date,
        status: TripStatus = .active,
        billingStoppedAt: Date? = nil,
        closedAt: Date? = nil,
        receipt: Receipt? = nil,
        serverReceiptID: Int? = nil,
        closedByOperator: Bool = false,
        photos: [InspectionPhoto] = []
    ) {
        self.id = id
        self.carID = carID
        self.carName = carName
        self.plate = plate
        self.thumbnailURL = thumbnailURL
        self.pricePerMinute = pricePerMinute
        self.startedAt = startedAt
        self.status = status
        self.billingStoppedAt = billingStoppedAt
        self.closedAt = closedAt
        self.receipt = receipt
        self.serverReceiptID = serverReceiptID
        self.closedByOperator = closedByOperator
        self.photos = photos
    }

    func photos(for stage: InspectionStage) -> [InspectionPhoto] {
        photos.filter { $0.stage == stage }.sorted { $0.side.sortIndex < $1.side.sortIndex }
    }
}

extension CarSide {
    var sortIndex: Int { CarSide.allCases.firstIndex(of: self) ?? 0 }
}
