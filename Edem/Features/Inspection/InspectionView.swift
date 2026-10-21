import PhotosUI
import SwiftUI

/// Сетка 2×2 из кадра 4: готовые снимки с зелёной галочкой и таймстемпом, пустые — пунктирная рамка.
struct InspectionContent: View {
    @Bindable var viewModel: InspectionViewModel
    let completeTitle: String
    let onComplete: () -> Void

    @State private var capturingSide: CarSide?
    @State private var isCameraPresented = false
    @State private var isLibraryPresented = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var loadError: String?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.title)
                        .font(.title.bold())
                    Text(viewModel.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.sides) { side in
                        Button {
                            capture(side)
                        } label: {
                            PhotoTile(
                                side: side,
                                photo: viewModel.photo(for: side),
                                isNext: side == viewModel.nextMissingSide
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    Text(viewModel.progressText)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    ProgressView(value: viewModel.progress)
                        .tint(Palette.accent)
                        .animation(.easeOut, value: viewModel.progress)
                }

                if let loadError {
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(Palette.danger)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if let side = viewModel.nextMissingSide {
                    Button {
                        capture(side)
                    } label: {
                        Label("Сделать фото", systemImage: "camera.fill")
                    }
                    .buttonStyle(.edemPrimary)
                } else {
                    Button(completeTitle, action: onComplete)
                        .buttonStyle(.edemPrimary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraPicker { image in
                store(image)
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $isLibraryPresented, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task { await loadFromLibrary(item) }
        }
    }

    private func capture(_ side: CarSide) {
        capturingSide = side
        loadError = nil
        // На симуляторе камеры нет — берём фото из галереи.
        if CameraPicker.isAvailable {
            isCameraPresented = true
        } else {
            isLibraryPresented = true
        }
    }

    private func loadFromLibrary(_ item: PhotosPickerItem) async {
        defer { libraryItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                loadError = "Не удалось открыть фото"
                return
            }
            store(image)
        } catch {
            loadError = "Не удалось открыть фото"
        }
    }

    private func store(_ image: UIImage) {
        guard let side = capturingSide, let data = image.inspectionJPEGData() else { return }
        withAnimation(.snappy) {
            viewModel.addPhoto(data, for: side)
        }
        capturingSide = nil
    }
}

private struct PhotoTile: View {
    let side: CarSide
    let photo: InspectionPhoto?
    let isNext: Bool

    var body: some View {
        ZStack {
            if let photo, let image = UIImage(data: photo.imageData) {
                Color.clear
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(side.title)
                                .font(.caption.weight(.semibold))
                            Text(Formatters.photoStamp.string(from: photo.takenAt))
                                .font(.caption2.monospacedDigit())
                        }
                        .foregroundStyle(.white)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Palette.success)
                            .padding(6)
                    }
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.surfaceMuted)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isNext ? Palette.accent : Palette.dashed, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    )
                    .overlay {
                        Image(systemName: "camera")
                            .font(.title2)
                            .foregroundStyle(Palette.accent)
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text(side.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Palette.accent)
                            .padding(10)
                    }
            }
        }
        .aspectRatio(1.05, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photo == nil ? "\(side.title): сделать фото" : "\(side.title): фото готово")
    }
}

/// Экран осмотра перед стартом аренды.
struct PickupInspectionScreen: View {
    @State private var viewModel: PickupViewModel
    @Environment(Router.self) private var router

    init(viewModel: PickupViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        InspectionContent(viewModel: viewModel.inspection, completeTitle: "Начать поездку") {
            viewModel.startRental()
            router.replace(with: [.activeRental])
        }
        .navigationTitle(viewModel.car.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension UIImage {
    /// Уменьшает снимок до 1280 px по длинной стороне и сжимает в JPEG.
    func inspectionJPEGData(maxDimension: CGFloat = 1280, quality: CGFloat = 0.7) -> Data? {
        let longest = max(size.width, size.height)
        let scale = min(1, maxDimension / max(longest, 1))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
