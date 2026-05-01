import Foundation

enum HTMLDocumentFetcher {
    static func fetchString(from url: URL, configuration: WebImagePickerConfiguration) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = configuration.requestTimeout
        if let ua = configuration.userAgent {
            request.setValue(ua, forHTTPHeaderField: "User-Agent")
        }

        let (bytes, response) = try await configuration.urlSession.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WebImagePickerError.invalidHTTPResponse
        }

        var data = Data()
        data.reserveCapacity(min(configuration.maximumHTMLDownloadBytes, 65_536))

        for try await byte in bytes {
            data.append(byte)
            if data.count > configuration.maximumHTMLDownloadBytes {
                throw WebImagePickerError.htmlTooLarge
            }
        }

        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return latin1
        }
        throw WebImagePickerError.htmlDecodingFailed
    }
}
