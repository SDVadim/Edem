import Foundation

/// Декоратор над реальным сервисом команд (OCP: поведение расширено без правки исходного класса).
///
/// - сетевые ошибки сводит к понятной `VehicleCommandError.noConnection`;
/// - в демо-режиме имитирует подземный паркинг: команда «висит» и падает без связи.
struct ConnectionAwareVehicleService: VehicleCommandService {
    let wrapped: VehicleCommandService
    let isConnectionLost: @Sendable () async -> Bool
    var simulatedFailureDelay: Duration = .seconds(4)

    func lockAndFinish(_ request: FinishRentalRequest) async throws -> FinishRentalResponse {
        if await isConnectionLost() {
            try await Task.sleep(for: simulatedFailureDelay)
            throw VehicleCommandError.noConnection
        }
        do {
            return try await wrapped.lockAndFinish(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch NetworkError.badStatus(let code) {
            throw VehicleCommandError.server(statusCode: code)
        } catch {
            throw VehicleCommandError.noConnection
        }
    }
}
