import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Ranks discovered images by on-device face detection (``VNDetectFaceRectanglesRequest``). Uses a small ranged GET per URL (same cap as dimension probing). Results are cached only for the duration of one ``orderedImages`` call.
enum DiscoveredImageFaceCountSorting {
    private static let probeByteLimit = 65_536

    static func orderedImages(
        _ images: [DiscoveredImage],
        descending: Bool,
        configuration: WebImagePickerConfiguration
    ) async -> [DiscoveredImage] {
        guard !images.isEmpty else { return images }
        let maxAnalyze = configuration.maximumFaceCountAnalysisImages
        guard maxAnalyze > 0 else { return images }

        let headCount = min(maxAnalyze, images.count)
        let head = Array(images[..<headCount])
        let tail = Array(images.dropFirst(headCount))

        let concurrency = max(1, configuration.maximumConcurrentImageLoads)
        var counts: [URL: Int] = [:]
        counts.reserveCapacity(head.count)

        var start = head.startIndex
        while start < head.endIndex {
            let end = head.index(start, offsetBy: concurrency, limitedBy: head.endIndex) ?? head.endIndex
            let chunk = Array(head[start..<end])

            let indexed: [(Int, URL, Int)] = await withTaskGroup(
                of: (Int, URL, Int).self,
                returning: [(Int, URL, Int)].self
            ) { group in
                for (offset, item) in chunk.enumerated() {
                    let url = item.sourceURL
                    group.addTask {
                        let data = await Self.fetchProbeData(for: url, configuration: configuration)
                        let n = data.map { Self.faceCount(from: $0) } ?? 0
                        return (offset, url, n)
                    }
                }
                var acc: [(Int, URL, Int)] = []
                for await row in group {
                    acc.append(row)
                }
                return acc.sorted { $0.0 < $1.0 }
            }

            for (_, url, n) in indexed {
                counts[url] = n
            }

            start = end
        }

        let sortedHead = sortStableByFaceCount(head, counts: counts, descending: descending)
        return sortedHead + tail
    }

    /// Stable sort by face count; ties keep discovery order (`counts` default is `0` per URL).
    internal static func sortStableByFaceCount(
        _ images: [DiscoveredImage],
        counts: [URL: Int],
        descending: Bool
    ) -> [DiscoveredImage] {
        images.enumerated().sorted { lhs, rhs in
            let lc = counts[lhs.element.sourceURL, default: 0]
            let rc = counts[rhs.element.sourceURL, default: 0]
            if descending {
                if lc != rc { return lc > rc }
            } else {
                if lc != rc { return lc < rc }
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    private static func faceCount(from data: Data) -> Int {
        guard let cgImage = cgImage(from: data) else { return 0 }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            return request.results?.count ?? 0
        } catch {
            return 0
        }
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(src) > 0 else { return nil }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 640,
        ]
        if let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOptions as CFDictionary) {
            return thumb
        }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
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
