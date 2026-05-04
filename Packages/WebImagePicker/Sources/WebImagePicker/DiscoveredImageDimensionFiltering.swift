import CoreGraphics
import Foundation

/// Probes each discovered image with a small ranged GET (default first 64KB) and drops URLs whose pixel dimensions fall outside optional bounds.
///
/// Servers that ignore `Range` may return a larger body; only the first ``probeByteLimit`` bytes (clamped by ``WebImagePickerConfiguration/maximumImageDownloadBytes``) are inspected. When dimensions cannot be parsed or the probe fails, the image is **kept** so discovery does not silently empty the grid on flaky hosts.
enum DiscoveredImageDimensionFiltering {
    private static let probeByteLimit = 65_536

    static func isEnabled(for configuration: WebImagePickerConfiguration) -> Bool {
        configuration.minimumImageDimensions != nil || configuration.maximumImageDimensions != nil
    }

    static func filtered(images: [DiscoveredImage], configuration: WebImagePickerConfiguration) async -> [DiscoveredImage] {
        guard isEnabled(for: configuration) else { return images }

        let concurrency = max(1, configuration.maximumConcurrentImageLoads)
        var output: [DiscoveredImage] = []
        output.reserveCapacity(images.count)

        var start = images.startIndex
        while start < images.endIndex {
            let end = images.index(start, offsetBy: concurrency, limitedBy: images.endIndex) ?? images.endIndex
            let chunk = Array(images[start..<end])

            let indexedOutcomes: [(Int, DiscoveredImage, Bool)] = await withTaskGroup(
                of: (Int, DiscoveredImage, Bool).self,
                returning: [(Int, DiscoveredImage, Bool)].self
            ) { group in
                for (offset, image) in chunk.enumerated() {
                    group.addTask {
                        let keep = await Self.shouldKeep(image: image, configuration: configuration)
                        return (offset, image, keep)
                    }
                }
                var acc: [(Int, DiscoveredImage, Bool)] = []
                for await item in group {
                    acc.append(item)
                }
                return acc.sorted { $0.0 < $1.0 }
            }

            for item in indexedOutcomes where item.2 {
                output.append(item.1)
            }

            start = end
        }

        return output
    }

    private static func shouldKeep(image: DiscoveredImage, configuration: WebImagePickerConfiguration) async -> Bool {
        guard let data = await fetchProbeData(for: image.sourceURL, configuration: configuration) else {
            return true
        }
        guard let dims = ImagePixelDimensions.read(from: data) else {
            return true
        }
        return passesBounds(width: dims.width, height: dims.height, configuration: configuration)
    }

    /// - Note: For each bound, a component `<= 0` means “no constraint” on that axis.
    internal static func passesBounds(width: Int, height: Int, configuration: WebImagePickerConfiguration) -> Bool {
        if let minSize = configuration.minimumImageDimensions {
            let minW = Int(minSize.width.rounded(.up))
            let minH = Int(minSize.height.rounded(.up))
            if minW > 0, width < minW { return false }
            if minH > 0, height < minH { return false }
        }
        if let maxSize = configuration.maximumImageDimensions {
            let maxW = Int(maxSize.width.rounded(.down))
            let maxH = Int(maxSize.height.rounded(.down))
            if maxW > 0, width > maxW { return false }
            if maxH > 0, height > maxH { return false }
        }
        return true
    }

    private static func fetchProbeData(for url: URL, configuration: WebImagePickerConfiguration) async -> Data? {
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
                return nil
            }
            return Data(data.prefix(byteLimit))
        } catch {
            return nil
        }
    }
}
