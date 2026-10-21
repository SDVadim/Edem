import UIKit

/// Загрузка картинок для UIKit-ячеек (в SwiftUI используется AsyncImage).
protocol ImageLoading: AnyObject {
    func image(for url: URL) async -> UIImage?
}

final class CachedImageLoader: ImageLoading {
    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 100
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        guard
            let response = try? await session.data(from: url),
            let image = UIImage(data: response.0)
        else { return nil }
        let prepared = await image.byPreparingForDisplay() ?? image
        cache.setObject(prepared, forKey: url as NSURL)
        return prepared
    }
}
