import MapKit
import SwiftUI

extension Coordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct MapScreen: View {
    @State private var viewModel: MapViewModel
    @Environment(Router.self) private var router
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
            span: MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.12)
        )
    )

    init(viewModel: MapViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Map(position: $camera) {
            ForEach(viewModel.cars) { car in
                Annotation(car.name, coordinate: car.coordinate.clCoordinate, anchor: .center) {
                    CarPin(pricePerMinute: car.pricePerMinute, isSelected: viewModel.selectedCarID == car.id)
                        .onTapGesture {
                            withAnimation(.snappy) { viewModel.select(car) }
                        }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                if let trip = viewModel.activeTrip {
                    Button {
                        router.push(.activeRental)
                    } label: {
                        ActiveTripBanner(trip: trip) { viewModel.liveCost(of: trip, at: $0) }
                    }
                    .buttonStyle(.plain)
                }
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            if let car = viewModel.selectedCar {
                SelectedCarCard(car: car) {
                    router.push(.car(car))
                } onClose: {
                    withAnimation(.snappy) { viewModel.select(nil) }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if viewModel.cars.isEmpty && viewModel.isLoading {
                ProgressView("Ищем машины рядом…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadIfNeeded() }
    }
}

/// Синий круг с машиной — «ваш автомобиль здесь» (иконка 2 в кадре 1).
struct CarPin: View {
    let pricePerMinute: Int?
    var isSelected = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "car.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(isSelected ? Palette.ink : Palette.accent, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .scaleEffect(isSelected ? 1.2 : 1)
            if let pricePerMinute {
                Text("\(pricePerMinute) ₽")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white, in: Capsule())
                    .foregroundStyle(Palette.ink)
            }
        }
        .animation(.snappy, value: isSelected)
        .accessibilityElement(children: .combine)
    }
}

/// Карточка поездки сверху карты: таймер и растущая сумма (кадр 1).
struct ActiveTripBanner: View {
    let trip: Trip
    let cost: (Date) -> Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(at: context.date))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text("\(trip.pricePerMinute) ₽/мин · \(trip.carName)")
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(Formatters.rubles(displayedCost(at: context.date)))
                    .font(.title3.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .foregroundStyle(Palette.ink)
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
    }

    private func title(at date: Date) -> String {
        switch trip.status {
        case .active:
            return "В пути · \(Formatters.duration(date.timeIntervalSince(trip.startedAt)))"
        case .closing, .finished:
            return "Завершаем аренду"
        }
    }

    private func displayedCost(at date: Date) -> Int {
        cost(trip.billingStoppedAt ?? date)
    }
}

private struct SelectedCarCard: View {
    let car: Car
    let onDetails: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                CarThumbnail(url: car.thumbnailURL)
                    .frame(width: 96, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(car.name)
                        .font(.headline)
                    Text(car.plate)
                        .font(.caption.monospaced())
                        .foregroundStyle(Palette.textSecondary)
                    HStack(spacing: 10) {
                        FuelBadge(level: car.fuelLevel)
                        Label(String(format: "%.1f", car.cleanliness), systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(Palette.textSecondary)
                .accessibilityLabel("Закрыть")
            }
            Button(action: onDetails) {
                Text("Подробнее · \(car.pricePerMinute) ₽/мин")
            }
            .buttonStyle(.edemPrimary)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }
}
