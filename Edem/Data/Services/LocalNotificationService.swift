import Foundation
import UserNotifications

/// Пуш «Аренда завершена» из кадра 8 стори-фрейма.
final class LocalNotificationService: NSObject, NotificationService, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func notifyRentalFinished(total: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Аренда завершена"
        content.body = "Машина закрыта. Списано \(total) ₽, чек на почте."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // Показываем баннер и когда приложение открыто — иначе пуш в демо не увидеть.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
