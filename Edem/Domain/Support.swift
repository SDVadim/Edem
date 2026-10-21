import Foundation

struct SupportMessage: Identifiable, Hashable, Sendable {
    enum Author: Hashable, Sendable {
        case user
        case operatorAgent(name: String)
        case system
    }

    let id: UUID
    let author: Author
    let text: String
    let sentAt: Date

    init(id: UUID = UUID(), author: Author, text: String, sentAt: Date = Date()) {
        self.id = id
        self.author = author
        self.text = text
        self.sentAt = sentAt
    }
}

/// Зачем пользователь пришёл в поддержку — от этого зависит стартовое сообщение и развязка.
enum SupportTopic: Hashable, Sendable {
    /// Машина не отвечает на команду закрытия (ветка ошибки из стори-фрейма).
    case carNotLocking(tripID: UUID)
    /// Спор о списании после поездки — «оспаривание в 1 клик» из CJM.
    case disputeCharge(tripID: UUID)
    case general
}
