import SwiftUI

struct CarDetailView: View {
    @State private var viewModel: CarDetailViewModel
    @Environment(Router.self) private var router

    init(viewModel: CarDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var car: Car { viewModel.car }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                gallery

                VStack(alignment: .leading, spacing: 6) {
                    Text(car.name)
                        .font(.title.bold())
                    HStack(spacing: 8) {
                        Text(car.plate)
                            .font(.subheadline.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.ink, lineWidth: 1.5))
                        Text(car.carClass.title)
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                        if !car.brand.isEmpty {
                            Text("· \(car.brand)")
                                .font(.subheadline)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    MetricTile(title: "Тариф", value: "\(car.pricePerMinute) ₽/мин", systemImage: "timer")
                    MetricTile(title: "Топливо", value: "\(car.fuelLevel)%", systemImage: "fuelpump.fill")
                    MetricTile(title: "Чистота", value: String(format: "%.1f", car.cleanliness), systemImage: "sparkles")
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Осмотр защищает вас", systemImage: "checkmark.shield.fill")
                        .font(.headline)
                        .foregroundStyle(Palette.success)
                    Text("Перед поездкой снимите машину с 4 сторон. Фото сохраняются с отметкой времени — "
                        + "если кто-то спишет с вас чужую царапину, у вас будет доказательство.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textTertiary)
                }
                .edemCard(fill: Palette.successSoft.opacity(0.5))
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("О машине")
                        .font(.headline)
                    Text(car.summary)
                        .font(.body)
                        .foregroundStyle(Palette.textTertiary)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .navigationTitle(car.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var gallery: some View {
        TabView {
            ForEach(viewModel.galleryURLs, id: \.self) { url in
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error != nil {
                        Image(systemName: "car.side.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Palette.placeholder)
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 260)
        .background(Palette.surface)
    }

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 8) {
            switch viewModel.availability {
            case .available:
                Button("Осмотреть и начать поездку") {
                    router.push(.pickupInspection(car))
                }
                .buttonStyle(.edemPrimary)
            case .inUseByMe:
                Button("Открыть поездку") {
                    router.push(.activeRental)
                }
                .buttonStyle(.edemPrimary)
            case .blockedByOtherTrip:
                Button("Осмотреть и начать поездку") {}
                    .buttonStyle(.edemPrimary)
                    .disabled(true)
                Text("Сначала завершите текущую аренду")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.accent)
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
