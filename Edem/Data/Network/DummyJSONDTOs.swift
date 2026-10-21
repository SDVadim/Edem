import Foundation

// Формат ответов https://dummyjson.com — публичного тестового API.

struct ProductListDTO: Decodable {
    let products: [ProductDTO]
}

struct ProductDTO: Decodable, Equatable {
    let id: Int
    let title: String
    let description: String
    let price: Double
    let rating: Double
    let brand: String?
    let thumbnail: String
    let images: [String]
}

struct CreatePostRequestDTO: Encodable {
    let title: String
    let body: String
    let userId: Int
}

struct CreatePostResponseDTO: Decodable {
    let id: Int
}

struct CreateCommentRequestDTO: Encodable {
    let body: String
    let postId: Int
    let userId: Int
}

struct CreateCommentResponseDTO: Decodable {
    let id: Int
    let body: String
}
