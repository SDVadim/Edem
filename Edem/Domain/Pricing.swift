import Foundation

struct Receipt: Hashable, Codable, Sendable {
    let rideMinutes: Int
    let rideCost: Int
    let insurance: Int
    /// Минуты между нажатием «Завершить» и фактическим закрытием машины. Не оплачиваются.
    let waitingMinutes: Int
    let waivedWaitingCost: Int

    var total: Int { rideCost + insurance }
}

/// Поминутный тариф. Отдельный тип, чтобы правила расчёта менялись в одном месте (SRP).
struct TariffCalculator: Sendable {
    var insuranceFee: Int = 12

    /// Оплачиваются только полные минуты, но не меньше одной.
    func billableMinutes(from start: Date, to end: Date) -> Int {
        let seconds = max(0, end.timeIntervalSince(start))
        return max(1, Int(seconds / 60))
    }

    func rideCost(pricePerMinute: Int, from start: Date, to end: Date) -> Int {
        billableMinutes(from: start, to: end) * pricePerMinute
    }

    /// Итог, который пользователь увидит в подтверждении: поездка + страховка.
    func expectedTotal(pricePerMinute: Int, from start: Date, to end: Date) -> Int {
        rideCost(pricePerMinute: pricePerMinute, from: start, to: end) + insuranceFee
    }

    func receipt(for trip: Trip, billingStoppedAt: Date, closedAt: Date) -> Receipt {
        let minutes = billableMinutes(from: trip.startedAt, to: billingStoppedAt)
        let waitingSeconds = max(0, closedAt.timeIntervalSince(billingStoppedAt))
        let waitingMinutes = Int(waitingSeconds / 60)
        return Receipt(
            rideMinutes: minutes,
            rideCost: minutes * trip.pricePerMinute,
            insurance: insuranceFee,
            waitingMinutes: waitingMinutes,
            waivedWaitingCost: waitingMinutes * trip.pricePerMinute
        )
    }
}
