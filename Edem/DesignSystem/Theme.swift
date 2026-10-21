import SwiftUI
import UIKit

/// Цвета из макета «Едем» (стори-фрейм завершения аренды).
enum Palette {
    static let ink = Color(hex: 0x111827)
    static let textSecondary = Color(hex: 0x6B7280)
    static let textTertiary = Color(hex: 0x4B5563)
    static let slate = Color(hex: 0x334155)
    static let surface = Color(hex: 0xF3F4F6)
    static let surfaceMuted = Color(hex: 0xF9FAFB)
    static let border = Color(hex: 0xE5E7EB)
    static let placeholder = Color(hex: 0xCBD5E1)
    static let dashed = Color(hex: 0x94A3B8)
    static let mapBackground = Color(hex: 0xE9EEF1)

    static let accent = Color(hex: 0x2F6BFF)
    static let success = Color(hex: 0x16A34A)
    static let successSoft = Color(hex: 0xDCFCE7)
    static let danger = Color(hex: 0xDC2626)
    static let dangerSoft = Color(hex: 0xFEE2E2)
    static let warning = Color(hex: 0xB45309)
    static let warningSoft = Color(hex: 0xFEF3C7)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    static let edemInk = UIColor(hex: 0x111827)
    static let edemSecondary = UIColor(hex: 0x6B7280)
    static let edemSurface = UIColor(hex: 0xF3F4F6)
    static let edemBorder = UIColor(hex: 0xE5E7EB)
    static let edemAccent = UIColor(hex: 0x2F6BFF)
    static let edemSuccess = UIColor(hex: 0x16A34A)
    static let edemWarning = UIColor(hex: 0xB45309)
    static let edemPlaceholder = UIColor(hex: 0xCBD5E1)
}

enum Formatters {
    static func rubles(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(number) ₽"
    }

    /// 00:41:18
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// 0:47
    static func shortDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Таймстемп на фото осмотра: «17.10 13:42:05».
    static let photoStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM HH:mm:ss"
        return formatter
    }()

    static let tripDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, HH:mm"
        return formatter
    }()
}
