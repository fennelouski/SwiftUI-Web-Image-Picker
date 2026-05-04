import Foundation

enum ImageDownloadService {
    static func download(from url: URL, configuration: WebImagePickerConfiguration) async throws -> WebImageSelection {
        var request = URLRequest(url: url)
        request.cachePolicy = configuration.cachePolicy.requestCachePolicy
        request.timeoutInterval = configuration.requestTimeout
        if let ua = configuration.userAgent {
            request.setValue(ua, forHTTPHeaderField: "User-Agent")
        }

        let (data, response) = try await configuration.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WebImagePickerError.downloadFailed
        }
        if data.count > configuration.maximumImageDownloadBytes {
            throw WebImagePickerError.imageTooLarge
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type")
        guard ImageTypeAllowlist.passesDownload(contentTypeHeader: contentType, configuration: configuration) else {
            throw WebImagePickerError.unsupportedImageType
        }
        return try makeSelection(data: data, contentType: contentType, sourceURL: url, configuration: configuration)
    }

    static func downloadSelections(
        urls: [URL],
        configuration: WebImagePickerConfiguration
    ) async throws -> [WebImageSelection] {
        var results: [URL: WebImageSelection] = [:]
        let chunkSize = configuration.maximumConcurrentImageLoads
        var index = urls.startIndex

        while index < urls.endIndex {
            let end = urls.index(index, offsetBy: chunkSize, limitedBy: urls.endIndex) ?? urls.endIndex
            let chunk = Array(urls[index..<end])

            try await withThrowingTaskGroup(of: (URL, WebImageSelection).self) { group in
                for url in chunk {
                    group.addTask {
                        let selection = try await download(from: url, configuration: configuration)
                        return (url, selection)
                    }
                }
                for try await (url, selection) in group {
                    results[url] = selection
                }
            }

            index = end
        }

        return urls.compactMap { results[$0] }
    }
}
