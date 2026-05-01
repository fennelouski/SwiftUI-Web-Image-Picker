import CoreGraphics
import Foundation
import ImageIO
import Vision

/// On-device text recognition for in-image search (``VNRecognizeTextRequest``), using the same ranged GET probe pattern as dimension / face analysis.
enum DiscoveredImageTextRecognition {
    private static let probeByteLimit = 384_000

    /// Builds a map of normalized image URL → concatenated recognized strings for the first chunk of URLs, respecting cancellation between batches.
    static func buildIndex(urls: [URL], configuration: WebImagePickerConfiguration) async -> [URL: String] {
        guard !urls.isEmpty else { return [:] }
        let concurrency = max(1, configuration.maximumConcurrentImageTextRecognition)
        var combined: [URL: String] = [:]
        combined.reserveCapacity(urls.count)

        var start = urls.startIndex
        while start < urls.endIndex {
            try? Task.checkCancellation()
            let end = urls.index(start, offsetBy: concurrency, limitedBy: urls.endIndex) ?? urls.endIndex
            let chunk = Array(urls[start..<end])

            let rows: [(URL, String)] = await withTaskGroup(of: (URL, String).self, returning: [(URL, String)].self) { group in
                for url in chunk {
                    group.addTask {
                        let data = await Self.fetchProbeData(for: url, configuration: configuration)
                        let text = data.flatMap {
                            Self.recognizedText(fromImageData: $0, languages: configuration.imageTextRecognitionLanguages)
                        } ?? ""
                        return (url, text)
                    }
                }
                var acc: [(URL, String)] = []
                for await row in group {
                    acc.append(row)
                }
                return acc
            }

            for (url, text) in rows where !text.isEmpty {
                combined[url] = text
            }

            start = end
        }

        return combined
    }

    /// Test hook: run Vision OCR on decoded image bytes.
    internal static func recognizedText(fromImageData data: Data, languages: [String]?) -> String? {
        guard let cgImage = cgImageForRecognition(from: data) else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        if let languages, !languages.isEmpty {
            request.recognitionLanguages = languages
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observations = request.results else { return nil }
        let parts = observations.compactMap { $0.topCandidates(1).first?.string }
        let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }

    private static func cgImageForRecognition(from data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(src) > 0 else { return nil }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 1280,
        ]
        if let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOptions as CFDictionary) {
            return thumb
        }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    private static func fetchProbeData(for url: URL, configuration: WebImagePickerConfiguration) async -> Data? {
        var request = URLRequest(url: url)
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
