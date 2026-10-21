import UIKit

final class FilterChipCell: UICollectionViewCell {
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 18
        contentView.layer.cornerCurve = .continuous
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    func configure(title: String, isSelected: Bool) {
        titleLabel.text = title
        titleLabel.textColor = isSelected ? .white : .edemInk
        contentView.backgroundColor = isSelected ? .edemInk : .edemSurface
        accessibilityLabel = title
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

final class CarCell: UICollectionViewCell {
    private let photoView = UIImageView()
    private let nameLabel = UILabel()
    private let plateLabel = UILabel()
    private let fuelLabel = UILabel()
    private let cleanlinessLabel = UILabel()
    private let priceLabel = UILabel()
    private let classLabel = PaddingLabel()
    private var imageTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        photoView.image = nil
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    func configure(with car: Car, imageLoader: ImageLoading) {
        nameLabel.text = car.name
        plateLabel.text = car.plate
        classLabel.text = car.carClass.title
        priceLabel.text = "\(car.pricePerMinute) ₽/мин"
        fuelLabel.attributedText = Self.iconText("fuelpump.fill", "\(car.fuelLevel)%", color: Self.fuelColor(car.fuelLevel))
        cleanlinessLabel.attributedText = Self.iconText(
            "sparkles", String(format: "%.1f", car.cleanliness), color: .edemSecondary
        )
        accessibilityLabel = "\(car.name), \(car.carClass.title), \(car.pricePerMinute) рублей в минуту, "
            + "топливо \(car.fuelLevel) процентов, чистота \(String(format: "%.1f", car.cleanliness))"

        imageTask?.cancel()
        photoView.image = nil
        guard let url = car.thumbnailURL else { return }
        imageTask = Task { [weak self] in
            let image = await imageLoader.image(for: url)
            guard !Task.isCancelled, let self else { return }
            UIView.transition(with: self.photoView, duration: 0.2, options: .transitionCrossDissolve) {
                self.photoView.image = image ?? UIImage(systemName: "car.side.fill")
            }
        }
    }

    private func setUpViews() {
        isAccessibilityElement = true
        accessibilityTraits = .button

        photoView.contentMode = .scaleAspectFit
        photoView.backgroundColor = .edemSurface
        photoView.tintColor = .edemPlaceholder
        photoView.layer.cornerRadius = 14
        photoView.layer.cornerCurve = .continuous
        photoView.clipsToBounds = true

        classLabel.font = .preferredFont(forTextStyle: .caption2)
        classLabel.textColor = .edemInk
        classLabel.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        classLabel.layer.cornerRadius = 8
        classLabel.clipsToBounds = true

        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.textColor = .edemInk
        nameLabel.numberOfLines = 2
        plateLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        plateLabel.textColor = .edemSecondary
        priceLabel.font = .preferredFont(forTextStyle: .subheadline).bold()
        priceLabel.textColor = .edemInk

        [nameLabel, plateLabel, priceLabel, fuelLabel, cleanlinessLabel].forEach {
            $0.adjustsFontForContentSizeCategory = true
        }

        let metrics = UIStackView(arrangedSubviews: [fuelLabel, cleanlinessLabel, UIView()])
        metrics.spacing = 10

        let stack = UIStackView(arrangedSubviews: [photoView, nameLabel, plateLabel, metrics, priceLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.setCustomSpacing(10, after: photoView)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        classLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(classLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            photoView.heightAnchor.constraint(equalTo: photoView.widthAnchor, multiplier: 0.7),
            classLabel.topAnchor.constraint(equalTo: photoView.topAnchor, constant: 8),
            classLabel.leadingAnchor.constraint(equalTo: photoView.leadingAnchor, constant: 8),
        ])
    }

    private static func fuelColor(_ level: Int) -> UIColor {
        switch level {
        case ..<30: return .systemRed
        case ..<55: return .edemWarning
        default: return .edemSuccess
        }
    }

    private static func iconText(_ symbol: String, _ text: String, color: UIColor) -> NSAttributedString {
        let font = UIFont.preferredFont(forTextStyle: .caption1).bold()
        let attachment = NSTextAttachment()
        attachment.image = UIImage(
            systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(font: font)
        )?.withTintColor(color, renderingMode: .alwaysOriginal)
        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(string: " \(text)", attributes: [.font: font, .foregroundColor: color]))
        return result
    }
}

/// UILabel с внутренними отступами для бейджа класса.
final class PaddingLabel: UILabel {
    var insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}

private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
