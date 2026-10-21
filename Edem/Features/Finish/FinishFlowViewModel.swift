import Foundation
import Observation

enum FinishStep: Hashable {
    case zone
    case photos
    case closing
    case support
    case receipt
}

struct ChecklistItem: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    var isDone = false
}

/// Сценарий завершения аренды из стори-фрейма: чек-лист → зона → фотоконтроль →
/// подтверждение → закрытие машины → чек, плюс ветка «нет связи» с исправлениями
/// из блока «Выводы по ветке».
@MainActor
@Observable
final class FinishFlowViewModel: Identifiable {
    enum ClosingState: Equatable {
        case idle
        case inProgress(startedAt: Date)
        case failed(attempt: Int, message: String)
        case done
    }

    /// Обещанное время ожидания из кадра 6. Дольше — честно меняем статус (вывод №2).
    static let promisedClosingSeconds: TimeInterval = 10

    var path: [FinishStep] = []
    var checklist: [ChecklistItem] = [
        ChecklistItem(id: "windows", title: "Закройте окна", systemImage: "window.vertical.closed"),
        ChecklistItem(id: "lights", title: "Выключите фары", systemImage: "lightbulb.slash"),
        ChecklistItem(id: "belongings", title: "Заберите вещи", systemImage: "bag"),
    ]
    var isConfirmPresented = false
    private(set) var trip: Trip
    private(set) var closingState: ClosingState = .idle
    private(set) var attempt = 0

    let inspection: InspectionViewModel
    let zone: ParkingZone?
    let carCoordinate: Coordinate?

    @ObservationIgnored private let rental: RentalSession
    @ObservationIgnored private let vehicleService: VehicleCommandService
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let tariff: TariffCalculator
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var closingTask: Task<Void, Never>?

    init(
        trip: Trip,
        car: Car?,
        rental: RentalSession,
        vehicleService: VehicleCommandService,
        notifications: NotificationService,
        tariff: TariffCalculator,
        inspection: InspectionViewModel,
        resumeClosing: Bool,
        now: @escaping () -> Date = Date.init
    ) {
        self.trip = trip
        self.rental = rental
        self.vehicleService = vehicleService
        self.notifications = notifications
        self.tariff = tariff
        self.inspection = inspection
        self.now = now
        carCoordinate = car?.coordinate
        // Зона завершения — квартал вокруг места, где стоит машина.
        zone = car.map { car in
            ParkingZone(
                center: Coordinate(latitude: car.coordinate.latitude + 0.0004, longitude: car.coordinate.longitude - 0.0003),
                radius: 250
            )
        }
        if resumeClosing {
            path = [.closing]
            startClosing()
        }
    }

    // MARK: Кадр 2 — чек-лист

    var checkedCount: Int { checklist.filter(\.isDone).count }

    var checklistProgressText: String { "Отмечено \(checkedCount) из \(checklist.count)" }

    var isChecklistComplete: Bool { checkedCount == checklist.count }

    func toggle(_ item: ChecklistItem) {
        guard let index = checklist.firstIndex(where: { $0.id == item.id }) else { return }
        checklist[index].isDone.toggle()
    }

    func proceedFromChecklist() {
        guard isChecklistComplete else { return }
        path.append(.zone)
    }

    // MARK: Кадр 3 — зона

    var isInZone: Bool {
        guard let zone, let carCoordinate else { return true }
        return zone.contains(carCoordinate)
    }

    func proceedFromZone() {
        path.append(.photos)
    }

    // MARK: Кадр 5 — подтверждение

    /// Сумма в диалоге подтверждения — «цена решения».
    var expectedTotal: Int {
        tariff.expectedTotal(pricePerMinute: trip.pricePerMinute, from: trip.startedAt, to: now())
    }

    func requestFinish() {
        guard inspection.isComplete else { return }
        isConfirmPresented = true
    }

    func confirmFinish() {
        isConfirmPresented = false
        // Вывод №1: счёт останавливается в момент нажатия «Завершить», а не после ответа машины.
        trip.billingStoppedAt = now()
        trip.status = .closing
        trip.photos.append(contentsOf: inspection.orderedPhotos)
        rental.update(trip)
        path.append(.closing)
        startClosing()
    }

    // MARK: Кадр 6 — закрытие машины

    var billingStoppedText: String {
        guard let stoppedAt = trip.billingStoppedAt else { return "" }
        let total = tariff.expectedTotal(pricePerMinute: trip.pricePerMinute, from: trip.startedAt, to: stoppedAt)
        return "Счёт остановлен в \(Formatters.time.string(from: stoppedAt)) · \(Formatters.rubles(total))"
    }

    func isSlow(at date: Date) -> Bool {
        guard case .inProgress(let startedAt) = closingState else { return false }
        return date.timeIntervalSince(startedAt) > Self.promisedClosingSeconds
    }

    func retry() {
        startClosing()
    }

    func openSupport() {
        closingTask?.cancel()
        path.append(.support)
    }

    private func startClosing() {
        closingTask?.cancel()
        attempt += 1
        closingState = .inProgress(startedAt: now())
        let request = FinishRentalRequest(
            tripID: trip.id,
            carID: trip.carID,
            plate: trip.plate,
            billingStoppedAt: trip.billingStoppedAt ?? now(),
            total: tariff.expectedTotal(
                pricePerMinute: trip.pricePerMinute,
                from: trip.startedAt,
                to: trip.billingStoppedAt ?? now()
            )
        )
        closingTask = Task { [weak self, vehicleService] in
            do {
                let response = try await vehicleService.lockAndFinish(request)
                guard !Task.isCancelled else { return }
                await self?.complete(receiptID: response.receiptID, byOperator: false)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.closingFailed(error)
            }
        }
    }

    private func closingFailed(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? "Не удалось связаться с автомобилем"
        closingState = .failed(attempt: attempt, message: message)
    }

    // MARK: Ветка 6г — поддержка закрыла машину удалённо

    func supportResolved() async {
        await complete(receiptID: nil, byOperator: true)
    }

    // MARK: Кадр 7 — чек

    var receipt: Receipt? { trip.receipt }

    private func complete(receiptID: Int?, byOperator: Bool) async {
        let closedAt = now()
        let billingStoppedAt = trip.billingStoppedAt ?? closedAt
        trip.closedAt = closedAt
        trip.receipt = tariff.receipt(for: trip, billingStoppedAt: billingStoppedAt, closedAt: closedAt)
        trip.serverReceiptID = receiptID
        trip.closedByOperator = byOperator
        trip.status = .finished
        rental.update(trip)
        closingState = .done
        path.append(.receipt)
        if let total = trip.receipt?.total {
            await notifications.notifyRentalFinished(total: total)
        }
    }

    func finish() {
        closingTask?.cancel()
        rental.clearCurrentTrip()
    }
}
