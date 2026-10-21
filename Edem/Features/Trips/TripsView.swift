import SwiftUI

struct TripsView: View {
    @State private var viewModel: TripsViewModel

    init(viewModel: TripsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            ForEach(viewModel.trips) { trip in
                NavigationLink(value: Route.trip(trip.id)) {
                    TripRow(trip: trip)
                }
            }
            .onDelete(perform: viewModel.delete)
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.trips.isEmpty {
                ContentUnavailableView(
                    "Поездок пока нет",
                    systemImage: "car",
                    description: Text("Здесь появятся чеки и акты осмотра ваших поездок")
                )
            }
        }
        .navigationTitle("Поездки")
        .onAppear { viewModel.reload() }
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            CarThumbnail(url: trip.thumbnailURL, cornerRadius: 10)
                .frame(width: 72, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.carName)
                    .font(.headline)
                Text(Formatters.tripDate.string(from: trip.startedAt))
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                if !trip.photos.isEmpty {
                    Label("Акт осмотра: \(trip.photos.count) фото", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(Palette.success)
                }
            }
            Spacer()
            if let total = trip.receipt?.total {
                Text(Formatters.rubles(total))
                    .font(.headline)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct TripDetailView: View {
    @State private var viewModel: TripDetailViewModel
    @State private var supportTopic: SupportTopic?
    let container: AppContainer

    init(viewModel: TripDetailViewModel, container: AppContainer) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
    }

    var body: some View {
        Group {
            if let trip = viewModel.trip {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(trip)
                        if let receipt = trip.receipt {
                            ReceiptCard(receipt: receipt, receiptID: trip.serverReceiptID)
                        }
                        InspectionAct(stage: .pickup, photos: viewModel.pickupPhotos)
                        InspectionAct(stage: .dropoff, photos: viewModel.dropoffPhotos)
                    }
                    .padding()
                }
                .safeAreaInset(edge: .bottom) {
                    // Возможность из CJM: оспаривание в 1 клик с актом осмотра.
                    Button {
                        supportTopic = .disputeCharge(tripID: trip.id)
                    } label: {
                        Label("Оспорить списание", systemImage: "exclamationmark.bubble")
                    }
                    .buttonStyle(.edemSecondary)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.bar)
                }
            } else {
                ContentUnavailableView("Поездка не найдена", systemImage: "questionmark.folder")
            }
        }
        .navigationTitle("Поездка")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $supportTopic) { topic in
            NavigationStack {
                SupportChatView(viewModel: container.makeSupportChatViewModel(topic: topic))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                supportTopic = nil
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Закрыть")
                        }
                    }
            }
        }
    }

    private func header(_ trip: Trip) -> some View {
        HStack(spacing: 14) {
            CarThumbnail(url: trip.thumbnailURL)
                .frame(width: 110, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.carName)
                    .font(.title3.bold())
                Text(trip.plate)
                    .font(.caption.monospaced())
                    .foregroundStyle(Palette.textSecondary)
                Text("\(Formatters.tripDate.string(from: trip.startedAt)) · \(viewModel.durationText)")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                if trip.closedByOperator {
                    Label("Закрыта оператором", systemImage: "headphones")
                        .font(.caption)
                        .foregroundStyle(Palette.warning)
                }
            }
        }
    }
}

extension SupportTopic: Identifiable {
    var id: String {
        switch self {
        case .carNotLocking(let id): return "lock-\(id)"
        case .disputeCharge(let id): return "dispute-\(id)"
        case .general: return "general"
        }
    }
}

/// Акт осмотра: фото с отметкой времени — доказательство в споре о повреждениях.
private struct InspectionAct: View {
    let stage: InspectionStage
    let photos: [InspectionPhoto]

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(stage.title)
                .font(.headline)
            if photos.isEmpty {
                Text("Фото нет")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(photos) { photo in
                        Color.clear
                            .aspectRatio(1.3, contentMode: .fit)
                            .overlay {
                                if let image = UIImage(data: photo.imageData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                            .overlay(alignment: .bottomLeading) {
                                Text("\(photo.side.title) · \(Formatters.photoStamp.string(from: photo.takenAt))")
                                    .font(.caption2.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.black.opacity(0.5))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(photo.side.title), снято \(Formatters.photoStamp.string(from: photo.takenAt))")
                    }
                }
            }
        }
    }
}
