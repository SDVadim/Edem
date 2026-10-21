import SwiftUI

/// Кадр 7 «Аренда завершена» и ветка 6д «Выход из ситуации».
struct ReceiptView: View {
    let trip: Trip
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StatusBadge(systemImage: "checkmark", tint: Palette.success, background: Palette.successSoft)
                    .padding(.top, 24)

                Text("Аренда завершена")
                    .font(.title.bold())

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)

                if let receipt = trip.receipt {
                    ReceiptCard(receipt: receipt, receiptID: trip.serverReceiptID)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button("Готово", action: onDone)
                .buttonStyle(.edemSuccess)
                .padding(.horizontal)
                .padding(.vertical, 12)
        }
        .navigationBarBackButtonHidden()
    }

    private var subtitle: String {
        trip.closedByOperator
            ? "Время ожидания связи мы не берём — извините за задержку"
            : "Машина закрыта. Спасибо, что вернули её в порядке!"
    }
}

struct ReceiptCard: View {
    let receipt: Receipt
    let receiptID: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Чек", systemImage: "doc.text")
                    .font(.headline)
                Spacer()
                if let receiptID {
                    Text("№ \(receiptID)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            ReceiptRow(title: "Поездка, \(receipt.rideMinutes) мин", value: Formatters.rubles(receipt.rideCost))
            ReceiptRow(title: "Страховка", value: Formatters.rubles(receipt.insurance))
            if receipt.waitingMinutes > 0 {
                ReceiptRow(
                    title: "Ожидание, \(receipt.waitingMinutes) мин",
                    value: Formatters.rubles(receipt.waivedWaitingCost),
                    isWaived: true
                )
            }
            Divider()
            ReceiptRow(title: "Итого", value: Formatters.rubles(receipt.total), isTotal: true)
        }
        .edemCard()
    }
}
