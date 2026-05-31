import Foundation

/// Lightweight ranged GET for tile metadata (dimensions, content type).
enum DiscoveredImageTileProbe {
    private static let probeByteLimit = 65_536

    struct Result: Sendable {
        var pixelWidth: Int?
        var pixelHeight: Int?
        var contentType: String?
    }

    static func probe(url: URL, configuration: WebImagePickerConfiguration) async -> Result {
        var request = URLRequest(url: url)
        request.cachePolicy = configuration.cachePolicy.requestCachePolicy
        request.timeoutInterval = configuration.requestTimeout
        if let ua = configuration.userAgent {
            request.setValue(ua, forHTTPHeaderField: "User-Agent")
        }

        let cap = max(1024, configuration.maximumImageDownloadBytes)
        let byteLimit = min(probeByteLimit, cap)
        request.setValue("bytes=0-\(byteLimit - 1)", forHTTPHeaderField: "Range")

        do {
            let (data, response) = try await configuration.urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return Result()
            }
            let prefix = Data(data.prefix(byteLimit))
            let dims = ImagePixelDimensions.read(from: prefix)
            let contentType = http.value(forHTTPHeaderField: "Content-Type")
            return Result(
                pixelWidth: dims?.width,
                pixelHeight: dims?.height,
                contentType: contentType
            )
        } catch {
            return Result()
        }
    }
}
