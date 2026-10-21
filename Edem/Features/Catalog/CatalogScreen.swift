import SwiftUI

/// SwiftUI-обёртка над UIKit-каталогом.
struct CarsCollectionView: UIViewControllerRepresentable {
    let cars: [Car]
    let selectedFilter: CatalogFilter
    let imageLoader: ImageLoading
    let onSelectFilter: (CatalogFilter) -> Void
    let onSelectCar: (Car) -> Void
    let onRefresh: () async -> Void

    func makeUIViewController(context: Context) -> CarsCollectionViewController {
        CarsCollectionViewController(imageLoader: imageLoader)
    }

    func updateUIViewController(_ controller: CarsCollectionViewController, context: Context) {
        controller.onSelectFilter = onSelectFilter
        controller.onSelectCar = onSelectCar
        controller.onRefresh = onRefresh
        controller.apply(cars: cars, filters: CatalogFilter.allCases, selectedFilter: selectedFilter)
    }
}

struct CatalogScreen: View {
    @State private var viewModel: CatalogViewModel
    @Environment(Router.self) private var router
    let imageLoader: ImageLoading

    init(viewModel: CatalogViewModel, imageLoader: ImageLoading) {
        _viewModel = State(initialValue: viewModel)
        self.imageLoader = imageLoader
    }

    var body: some View {
        CarsCollectionView(
            cars: viewModel.visibleCars,
            selectedFilter: viewModel.filter,
            imageLoader: imageLoader,
            onSelectFilter: { filter in viewModel.filter = filter },
            onSelectCar: { car in router.push(.car(car)) },
            onRefresh: { await viewModel.refresh() }
        )
        .overlay {
            if viewModel.visibleCars.isEmpty {
                if viewModel.isLoading {
                    ProgressView()
                } else if let message = viewModel.errorMessage {
                    ContentUnavailableView("Нет машин", systemImage: "wifi.slash", description: Text(message))
                } else {
                    ContentUnavailableView(
                        "Ничего не найдено",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Попробуйте другой фильтр")
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let message = viewModel.errorMessage, !viewModel.visibleCars.isEmpty {
                Text(message)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle("Автомобили")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadIfNeeded() }
    }
}
