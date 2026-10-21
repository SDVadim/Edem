import MapKit
import SwiftUI

/// Кадр 1 «Подъехала к дому»: карта с машиной, растущая сумма, управление дверями.
struct ActiveRentalView: View {
    @State private var viewModel: ActiveRentalViewModel
    @Environment(Router.self) private var router
    @State private var finishFlow: FinishFlowViewModel?
    let container: AppContainer

    init(viewModel: ActiveRentalViewModel, container: AppContainer) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
    }

    var body: some View {
        Group {
            if let trip = viewModel.trip {
                content(trip: trip)
            } else {
                ContentUnavailableView(
                    "Нет активной аренды",
                    systemImage: "car",
                    description: Text("Выберите машину на карте или в каталоге")
                )
            }
        }
        .navigationTitle("Поездка")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $finishFlow) { flow in
            FinishFlowView(viewModel: flow, container: container) {
                finishFlow = nil
                router.popToRoot()
            }
        }
    }

    private func content(trip: Trip) -> some View {
        ZStack(alignment: .top) {
            Map(initialPosition: cameraPosition) {
                if let car = viewModel.car {
                    Annotation(car.name, coordinate: car.coordinate.clCoordinate) {
                        CarPin(pricePerMinute: nil)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea(edges: .bottom)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("В пути · \(viewModel.elapsedText(at: context.date))")
                            .font(.headline)
                            .monospacedDigit()
                        Text("\(trip.pricePerMinute) ₽/мин")
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    Text(Formatters.rubles(viewModel.cost(at: context.date)))
                        .font(.title2.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .foregroundStyle(Palette.ink)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                .padding()
                .accessibilityElement(children: .combine)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomSheet(trip: trip)
        }
    }

    private func bottomSheet(trip: Trip) -> some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Palette.border)
                .frame(width: 36, height: 5)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.carName)
                        .font(.headline)
                    Text(trip.plate)
                        .font(.caption.monospaced())
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                if let message = viewModel.lockMessage {
                    Text(message)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Palette.textSecondary)
                        .transition(.opacity)
                }
            }

            if viewModel.isClosingPending {
                Label("Завершение не подтверждено машиной. Счёт уже остановлен.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Palette.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Palette.warningSoft, in: RoundedRectangle(cornerRadius: 12))
                Button("Продолжить завершение") {
                    finishFlow = container.makeFinishFlowViewModel(trip: trip, resumeClosing: true)
                }
                .buttonStyle(.edemPrimary)
            } else {
                HStack(spacing: 12) {
                    DoorButton(title: "Закрыть", systemImage: "lock", isActive: viewModel.doorsLocked) {
                        withAnimation { viewModel.setDoorsLocked(true) }
                    }
                    DoorButton(title: "Открыть", systemImage: "lock.open", isActive: !viewModel.doorsLocked) {
                        withAnimation { viewModel.setDoorsLocked(false) }
                    }
                }
                Button("Завершить аренду") {
                    finishFlow = container.makeFinishFlowViewModel(trip: trip, resumeClosing: false)
                }
                .buttonStyle(.edemPrimary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
    }

    private var cameraPosition: MapCameraPosition {
        guard let car = viewModel.car else { return .automatic }
        return .region(MKCoordinateRegion(
            center: car.coordinate.clCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
        ))
    }
}

private struct DoorButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(Palette.ink)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isActive ? Palette.ink.opacity(0.4) : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: isActive)
    }
}
