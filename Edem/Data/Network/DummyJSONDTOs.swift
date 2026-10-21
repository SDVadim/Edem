import Foundation

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
