import SwiftUI

/// Крупная кнопка шага: тёмная — главное действие, зелёная — «всё хорошо», красная — необратимое.
struct EdemButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case success
        case danger
        case secondary
    }

    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Palette.border, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var background: Color {
        guard isEnabled else { return Palette.border }
        switch kind {
        case .primary: return Palette.ink
        case .success: return Palette.success
        case .danger: return Palette.danger
        case .secondary: return Color(.systemBackground)
        }
    }

    private var foreground: Color {
        guard isEnabled else { return Palette.textSecondary }
        return kind == .secondary ? Palette.ink : .white
    }
}

extension ButtonStyle where Self == EdemButtonStyle {
    static var edemPrimary: EdemButtonStyle { EdemButtonStyle(kind: .primary) }
    static var edemSuccess: EdemButtonStyle { EdemButtonStyle(kind: .success) }
    static var edemDanger: EdemButtonStyle { EdemButtonStyle(kind: .danger) }
    static var edemSecondary: EdemButtonStyle { EdemButtonStyle(kind: .secondary) }
}

/// Светлая карточка с рамкой (чек, чек-лист).
struct CardModifier: ViewModifier {
    var fill: Color = Palette.surfaceMuted

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.border, lineWidth: 1)
            )
    }
}

extension View {
    func edemCard(fill: Color = Palette.surfaceMuted) -> some View {
        modifier(CardModifier(fill: fill))
    }
}

/// Круглый значок статуса (успех, ошибка, замок) из кадров 5–7.
struct StatusBadge: View {
    let systemImage: String
    let tint: Color
    let background: Color
    var size: CGFloat = 88

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(background, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Индикатор топлива: зелёный, жёлтый или красный в зависимости от уровня.
struct FuelBadge: View {
    let level: Int

    var body: some View {
        Label("\(level)%", systemImage: "fuelpump.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .accessibilityLabel("Топливо \(level) процентов")
    }

    private var color: Color {
        switch level {
        case ..<30: return Palette.danger
        case ..<55: return Palette.warning
        default: return Palette.success
        }
    }
}

/// Строка «название — сумма» в чеке.
struct ReceiptRow: View {
    let title: String
    let value: String
    var isTotal = false
    var isWaived = false

    var body: some View {
        HStack {
            Text(title)
                .font(isTotal ? .headline : .subheadline)
                .foregroundStyle(isWaived ? Palette.success : (isTotal ? Palette.ink : Palette.textTertiary))
            Spacer()
            Text(value)
                .font(isTotal ? .title3.bold() : .subheadline.weight(.medium))
                .foregroundStyle(isWaived ? Palette.textSecondary : Palette.ink)
                .strikethrough(isWaived)
                .monospacedDigit()
        }
    }
}

struct CarThumbnail: View {
    let url: URL?
    var cornerRadius: CGFloat = 12

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                Image(systemName: "car.side.fill")
                    .font(.title)
                    .foregroundStyle(Palette.placeholder)
            default:
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
