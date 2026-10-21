import Foundation
import Observation

@MainActor
@Observable
final class SupportChatViewModel {
    let topic: SupportTopic
    private(set) var messages: [SupportMessage] = []
    private(set) var isSending = false
    private(set) var isOperatorTyping = false
    private(set) var isResolved = false
    private(set) var errorMessage: String?
    var draft: String

    let operatorName = "Лена"

    @ObservationIgnored private let service: SupportService

    init(topic: SupportTopic, service: SupportService) {
        self.topic = topic
        self.service = service
        draft = Self.initialDraft(for: topic)
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    /// Кнопка «Посмотреть чек» появляется, когда оператор закрыл машину.
    var resolutionActionTitle: String? {
        guard isResolved else { return nil }
        switch topic {
        case .carNotLocking: return "Посмотреть чек"
        case .disputeCharge, .general: return nil
        }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let sent = try await service.send(text: text, topic: topic)
            draft = ""
            messages.append(sent)
            await awaitOperatorIfNeeded()
        } catch {
            errorMessage = "Сообщение не отправлено. Проверьте интернет и попробуйте ещё раз."
        }
    }

    private func awaitOperatorIfNeeded() async {
        guard !isResolved, !isOperatorTyping else { return }
        // Как в кадре 6г: ожидание обозначено, тревога ниже.
        messages.append(SupportMessage(author: .system, text: "Оператор ответит через ~5 мин"))
        isOperatorTyping = true
        defer { isOperatorTyping = false }
        do {
            let reply = try await service.operatorReply(for: topic)
            messages.append(reply)
            isResolved = topic != .general
        } catch {
            errorMessage = "Оператор пока не ответил — мы пришлём уведомление."
        }
    }

    private static func initialDraft(for topic: SupportTopic) -> String {
        switch topic {
        case .carNotLocking:
            return "Машина не закрывается, нет связи — я в подземном паркинге"
        case .disputeCharge:
            return "Пришло списание за повреждение, которого не было. Прикладываю акт осмотра с фото."
        case .general:
            return ""
        }
    }
}
