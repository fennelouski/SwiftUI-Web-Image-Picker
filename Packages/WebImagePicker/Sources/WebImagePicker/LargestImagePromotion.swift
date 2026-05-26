import Foundation

/// Promotes the top 10% of images by pixel area to the front of the list.
///
/// Uses the same ranged-GET probe infrastructure as ``DiscoveredImageDimensionFiltering`` to read
/// pixel dimensions from image headers without downloading full images.
enum LargestImagePromotion {
    private static let probeByteLimit = 65_536
    private static let promotionPercentile = 0.10

    static func promoted(images: [DiscoveredImage], configuration: WebImagePickerConfiguration) async -> [DiscoveredImage] {
        guard images.count >= 2 else { return images }

        let concurrency = max(1, configuration.maximumConcurrentImageLoads)
        var areas: [(index: Int, area: Int)] = []
        areas.reserveCapacity(images.count)

        var start = images.startIndex
        while start < images.endIndex {
            let end = images.index(start, offsetBy: concurrency, limitedBy: images.endIndex) ?? images.endIndex
            let chunk = Array(images[start..<end])

            let results: [(Int, Int)] = await withTaskGroup(
                of: (Int, Int).self,
                returning: [(Int, Int)].self
            ) { group in
                for (offset, image) in chunk.enumerated() {
                    let globalIndex = start + offset
                    group.addTask {
                        let area = await Self.probePixelArea(for: image.sourceURL, configuration: configuration)
                        return (globalIndex, area)
                    }
                }
                var acc: [(Int, Int)] = []
                for await item in group {
                    acc.append(item)
                }
                return acc
            }

            areas.append(contentsOf: results.map { (index: $0.0, area: $0.1) })
            start = end
        }

        let knownAreas = areas.filter { $0.area > 0 }.map(\.area).sorted()
        guard !knownAreas.isEmpty else { return images }

        let promotionCount = max(1, Int(ceil(Double(images.count) * promotionPercentile)))
        let p90Index = max(0, knownAreas.count - promotionCount)
        let threshold = knownAreas[p90Index]

        let areaByIndex = Dictionary(uniqueKeysWithValues: areas.map { ($0.index, $0.area) })

        var promoted: [DiscoveredImage] = []
        var rest: [DiscoveredImage] = []
        promoted.reserveCapacity(promotionCount)
        rest.reserveCapacity(images.count - promotionCount)

        for (index, image) in images.enumerated() {
            let area = areaByIndex[index] ?? 0
            if area >= threshold && area > 0 && promoted.count < promotionCount {
                promoted.append(image)
            } else {
                rest.append(image)
            }
        }

        return promoted + rest
    }

    private static func probePixelArea(for url: URL, configuration: WebImagePickerConfiguration) async -> Int {
        guard let data = await fetchProbeData(for: url, configuration: configuration) else {
            return 0
        }
        guard let dims = ImagePixelDimensions.read(from: data) else {
            return 0
        }
        return dims.width * dims.height
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
