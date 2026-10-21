import Foundation
import SwiftData

/// Composition root: единственное место, где создаются конкретные реализации.
/// Экраны получают готовые ViewModel через фабричные методы и не знают о сети и базе.
@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let rental: RentalManager
    let settings: UserDefaultsSettingsStore
    let imageLoader: ImageLoading

    private let carRepository: CarRepository
    private let tripRepository: TripRepository
    private let vehicleService: VehicleCommandService
    private let supportService: SupportService
    private let notifications: NotificationService
    private let tariff = TariffCalculator()

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            modelContainer = try ModelContainer(
                for: CarEntity.self, TripEntity.self, InspectionPhotoEntity.self,
                configurations: configuration
            )
        } catch {
            fatalError("Не удалось открыть базу SwiftData: \(error)")
        }
        let context = modelContainer.mainContext

        let api = JSONAPIClient(http: URLSessionHTTPClient())
        let settings = UserDefaultsSettingsStore()
        self.settings = settings

        carRepository = DefaultCarRepository(
            remote: DummyJSONCarsDataSource(api: api),
            cache: SwiftDataCarsCache(context: context)
        )
        let tripRepository = SwiftDataTripRepository(context: context)
        self.tripRepository = tripRepository
        rental = RentalManager(repository: tripRepository)
        vehicleService = ConnectionAwareVehicleService(
            wrapped: DummyJSONVehicleCommandService(api: api),
            isConnectionLost: { await MainActor.run { settings.simulateNoConnection } }
        )
        supportService = DummyJSONSupportService(api: api)
        notifications = LocalNotificationService()
        imageLoader = CachedImageLoader()
    }

    func requestNotificationPermission() async {
        await notifications.requestAuthorization()
    }

    // MARK: - Фабрики ViewModel

    func makeMapViewModel() -> MapViewModel {
        MapViewModel(repository: carRepository, rental: rental, tariff: tariff)
    }

    func makeCatalogViewModel() -> CatalogViewModel {
        CatalogViewModel(repository: carRepository)
    }

    func makeCarDetailViewModel(car: Car) -> CarDetailViewModel {
        CarDetailViewModel(car: car, rental: rental)
    }

    func makePickupViewModel(car: Car) -> PickupViewModel {
        PickupViewModel(car: car, rental: rental, inspection: InspectionViewModel(stage: .pickup))
    }

    func makeActiveRentalViewModel() -> ActiveRentalViewModel {
        ActiveRentalViewModel(rental: rental, repository: carRepository, tariff: tariff)
    }

    func makeFinishFlowViewModel(trip: Trip, resumeClosing: Bool) -> FinishFlowViewModel {
        FinishFlowViewModel(
            trip: trip,
            car: carRepository.cachedCars().first { $0.id == trip.carID },
            rental: rental,
            vehicleService: vehicleService,
            notifications: notifications,
            tariff: tariff,
            inspection: InspectionViewModel(stage: .dropoff),
            resumeClosing: resumeClosing
        )
    }

    func makeSupportChatViewModel(topic: SupportTopic) -> SupportChatViewModel {
        SupportChatViewModel(topic: topic, service: supportService)
    }

    func makeTripsViewModel() -> TripsViewModel {
        TripsViewModel(repository: tripRepository)
    }

    func makeTripDetailViewModel(tripID: UUID) -> TripDetailViewModel {
        TripDetailViewModel(tripID: tripID, repository: tripRepository)
    }

    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(settings: settings, trips: tripRepository)
    }
}
