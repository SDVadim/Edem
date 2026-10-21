import Foundation

enum DummyJSONEndpoint {
    static let baseURL = URL(string: "https://dummyjson.com")!

    static let vehicles = baseURL.appendingPathComponent("products/category/vehicle")
    static let addPost = baseURL.appendingPathComponent("posts/add")
    static let addComment = baseURL.appendingPathComponent("comments/add")
}

/// Машины берутся из категории `vehicle` каталога DummyJSON.
struct DummyJSONCarsDataSource: CarsRemoteDataSource {
    let api: JSONAPIClient
    var mapper = CarMapper()

    func fetchCars() async throws -> [Car] {
        let list: ProductListDTO = try await api.get(DummyJSONEndpoint.vehicles)
        return mapper.map(list.products)
    }
}

/// Отчёт о завершении аренды уходит на сервер как POST, в ответ приходит id — номер чека.
struct DummyJSONVehicleCommandService: VehicleCommandService {
    let api: JSONAPIClient
    var userID = 1

    func lockAndFinish(_ request: FinishRentalRequest) async throws -> FinishRentalResponse {
        let body = CreatePostRequestDTO(
            title: "Завершение аренды \(request.plate)",
            body: "trip=\(request.tripID.uuidString); car=\(request.carID); "
                + "billingStoppedAt=\(ISO8601DateFormatter().string(from: request.billingStoppedAt)); "
                + "total=\(request.total)",
            userId: userID
        )
        let response: CreatePostResponseDTO = try await api.post(DummyJSONEndpoint.addPost, body: body)
        return FinishRentalResponse(receiptID: response.id)
    }
}

/// Сообщения в поддержку отправляются как комментарии DummyJSON.
struct DummyJSONSupportService: SupportService {
    let api: JSONAPIClient
    var userID = 1
    var operatorName = "Лена"
    var operatorDelay: Duration = .seconds(3)

    func send(text: String, topic: SupportTopic) async throws -> SupportMessage {
        let body = CreateCommentRequestDTO(body: text, postId: 1, userId: userID)
        let response: CreateCommentResponseDTO = try await api.post(DummyJSONEndpoint.addComment, body: body)
        return SupportMessage(author: .user, text: response.body)
    }

    /// У DummyJSON нет живых операторов, поэтому ответ формируется локально с задержкой,
    /// как если бы пришёл по веб-сокету.
    func operatorReply(for topic: SupportTopic) async throws -> SupportMessage {
        try await Task.sleep(for: operatorDelay)
        let text: String
        switch topic {
        case .carNotLocking:
            text = "Закрыли машину удалённо и завершили аренду по времени вашего обращения. Ожидание не спишем."
        case .disputeCharge:
            text = "Сверили ваши фото осмотра с таймстемпами — повреждение было до вашей поездки. Списание отменено."
        case .general:
            text = "Здравствуйте! Чем можем помочь?"
        }
        return SupportMessage(author: .operatorAgent(name: operatorName), text: text)
    }
}
