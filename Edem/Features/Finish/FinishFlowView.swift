import MapKit
import SwiftUI

struct FinishFlowView: View {
    @Bindable var viewModel: FinishFlowViewModel
    let container: AppContainer
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ChecklistStepView(viewModel: viewModel) { dismiss() }
                .navigationDestination(for: FinishStep.self) { step in
                    switch step {
                    case .zone:
                        ZoneStepView(viewModel: viewModel)
                    case .photos:
                        InspectionContent(viewModel: viewModel.inspection, completeTitle: "Завершить аренду") {
                            viewModel.requestFinish()
                        }
                    case .closing:
                        ClosingStepView(viewModel: viewModel)
                    case .support:
                        SupportChatView(
                            viewModel: container.makeSupportChatViewModel(topic: .carNotLocking(tripID: viewModel.trip.id))
                        ) {
                            await viewModel.supportResolved()
                        }
                        .navigationBarBackButtonHidden(viewModel.trip.status == .finished)
                    case .receipt:
                        ReceiptView(trip: viewModel.trip) {
                            viewModel.finish()
                            onDone()
                        }
                    }
                }
        }
        .tint(Palette.accent)
        .overlay {
            if viewModel.isConfirmPresented {
                ConfirmFinishDialog(total: viewModel.expectedTotal) {
                    withAnimation(.snappy) { viewModel.isConfirmPresented = false }
                } onConfirm: {
                    withAnimation(.snappy) { viewModel.confirmFinish() }
                }
                .transition(.opacity)
            }
        }
        .animation(.snappy, value: viewModel.isConfirmPresented)
    }
}

// MARK: - Кадр 2 «Перед завершением»

private struct ChecklistStepView: View {
    @Bindable var viewModel: FinishFlowViewModel
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Перед завершением")
                        .font(.title.bold())
                    Text("Проверьте, чтобы следующий водитель получил машину в порядке")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }

                VStack(spacing: 10) {
                    ForEach(viewModel.checklist) { item in
                        Button {
                            withAnimation(.snappy) { viewModel.toggle(item) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                                    .font(.title2)
                                    .foregroundStyle(item.isDone ? Palette.success : Palette.textSecondary)
                                    .contentTransition(.symbolEffect(.replace))
                                Text(item.title)
                                    .font(.body)
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                Image(systemName: item.systemImage)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .padding(16)
                            .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Palette.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(item.isDone ? .isSelected : [])
                        .sensoryFeedback(.selection, trigger: item.isDone)
                    }
                }

                Text(viewModel.checklistProgressText)
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button("Далее") { viewModel.proceedFromChecklist() }
                .buttonStyle(.edemPrimary)
                .disabled(!viewModel.isChecklistComplete)
                .padding(.horizontal)
                .padding(.vertical, 12)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Выйти — аренда продолжится")
            }
        }
    }
}

// MARK: - Кадр 3 «Проверка зоны»

private struct ZoneStepView: View {
    @Bindable var viewModel: FinishFlowViewModel

    var body: some View {
        VStack(spacing: 0) {
            Map(initialPosition: cameraPosition) {
                if let zone = viewModel.zone {
                    MapCircle(center: zone.center.clCoordinate, radius: zone.radius)
                        .foregroundStyle(Palette.success.opacity(0.18))
                        .stroke(Palette.success, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    Annotation("Парковка", coordinate: zone.center.clCoordinate) {
                        Text("P")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Palette.success, in: RoundedRectangle(cornerRadius: 7))
                    }
                    .annotationTitles(.hidden)
                }
                if let coordinate = viewModel.carCoordinate {
                    Annotation("Машина", coordinate: coordinate.clCoordinate) {
                        CarPin(pricePerMinute: nil)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))

            VStack(spacing: 12) {
                if viewModel.isInZone {
                    Label("Вы в зоне завершения", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Palette.successSoft, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Label("Машина вне зоны завершения", systemImage: "xmark.octagon.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Palette.dangerSoft, in: RoundedRectangle(cornerRadius: 12))
                }
                // Вывод №3: предупреждаем о связи заранее, а не после ошибки.
                Label(
                    "В подземном паркинге может пропасть связь с машиной — лучше завершать у выезда.",
                    systemImage: "antenna.radiowaves.left.and.right.slash"
                )
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Продолжить") { viewModel.proceedFromZone() }
                    .buttonStyle(.edemPrimary)
                    .disabled(!viewModel.isInZone)
            }
            .padding()
            .background(.white)
        }
        .navigationTitle("Проверка зоны")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cameraPosition: MapCameraPosition {
        guard let zone = viewModel.zone else { return .automatic }
        return .region(MKCoordinateRegion(
            center: zone.center.clCoordinate,
            latitudinalMeters: zone.radius * 3.2,
            longitudinalMeters: zone.radius * 3.2
        ))
    }
}

// MARK: - Кадр 5 «Подтверждение»

private struct ConfirmFinishDialog: View {
    let total: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 14) {
                StatusBadge(systemImage: "lock.fill", tint: Palette.danger, background: Palette.dangerSoft, size: 56)
                Text("Завершить аренду?")
                    .font(.title3.bold())
                Text("Машина закроется. Отменить это действие будет нельзя.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                HStack {
                    Text("Итого")
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Text(Formatters.rubles(total))
                        .font(.title3.bold())
                        .monospacedDigit()
                }
                .padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                HStack(spacing: 10) {
                    Button("Отмена", action: onCancel)
                        .buttonStyle(.edemSecondary)
                    Button("Завершить", action: onConfirm)
                        .buttonStyle(.edemDanger)
                }
            }
            .padding(20)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 28)
            .accessibilityAddTraits(.isModal)
        }
    }
}

// MARK: - Кадр 6 и ветка 6а–6в «Закрываем автомобиль…»

private struct ClosingStepView: View {
    @Bindable var viewModel: FinishFlowViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 20) {
                Spacer()
                switch viewModel.closingState {
                case .idle, .inProgress, .done:
                    progressContent(at: context.date)
                case let .failed(attempt, _):
                    failureContent(attempt: attempt)
                }
                Spacer()
                Label(viewModel.billingStoppedText, systemImage: "timer")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                actions
            }
            .padding()
        }
        .navigationBarBackButtonHidden()
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private func progressContent(at date: Date) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "wave.3.left")
            Image(systemName: "car.fill")
                .font(.system(size: 44))
            Image(systemName: "wave.3.right")
        }
        .font(.system(size: 30))
        .foregroundStyle(Palette.accent.opacity(0.8))
        .symbolEffect(.variableColor.iterative, options: .repeating)

        ProgressView()
            .controlSize(.large)
            .tint(Palette.accent)

        Text("Закрываем автомобиль…")
            .font(.title2.bold())
            .multilineTextAlignment(.center)

        if viewModel.isSlow(at: date) {
            // Вывод №1–2: не молчим, когда обещание нарушено, и прямо говорим, что деньги не капают.
            Text("Дольше обычного. Счёт уже остановлен — за ожидание ничего не спишем. Мы продолжаем попытки.")
                .font(.subheadline)
                .foregroundStyle(Palette.warning)
                .multilineTextAlignment(.center)
        } else {
            Text("Обычно это занимает до 10 секунд. Не отходите от машины.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func failureContent(attempt: Int) -> some View {
        StatusBadge(systemImage: "exclamationmark.triangle.fill", tint: Palette.danger, background: Palette.dangerSoft)

        Text("Не удалось связаться с автомобилем")
            .font(.title2.bold())
            .multilineTextAlignment(.center)

        Text("Похоже, здесь нет мобильной связи (например, в подземном паркинге). "
            + "Минуты больше не списываются — счёт остановлен в момент нажатия «Завершить».")
            .font(.subheadline)
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.center)

        if attempt > 1 {
            Label("Попытка \(attempt) — не удалось", systemImage: "antenna.radiowaves.left.and.right.slash")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Palette.ink, in: Capsule())
        }
    }

    @ViewBuilder
    private var actions: some View {
        if case .failed = viewModel.closingState {
            Button {
                viewModel.retry()
            } label: {
                Label("Повторить", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.edemPrimary)
            // Вывод №4–5: поддержка — полноценная кнопка с понятным временем ответа.
            Button {
                viewModel.openSupport()
            } label: {
                Label("Закрыть через оператора · ~5 мин", systemImage: "headphones")
            }
            .buttonStyle(.edemSecondary)
        }
    }
}
