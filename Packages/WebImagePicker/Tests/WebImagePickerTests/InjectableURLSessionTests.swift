import XCTest
@testable import WebImagePicker

private final class StubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var _handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func setHandler(_ handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?) {
        lock.lock()
        defer { lock.unlock() }
        _handler = handler
    }

    private static func handlerForRequest() -> ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        lock.lock()
        defer { lock.unlock() }
        return _handler
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handlerForRequest() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func urlSessionWithStub() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
}

final class InjectableURLSessionTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.setHandler(nil)
        super.tearDown()
    }

    func testHTMLDocumentFetcherUsesInjectableSession() async throws {
        let pageURL = URL(string: "https://example.com/page")!
        let html = #"<html><body><img src="/x.png" alt=""></body></html>"#
        StubURLProtocol.setHandler { request in
            XCTAssertEqual(request.url, pageURL)
            let response = HTTPURLResponse(
                url: pageURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )!
            return (response, Data(html.utf8))
        }

        var config = WebImagePickerConfiguration(allowedURLSchemes: ["https"])
        config.urlSession = urlSessionWithStub()

        let result = try await HTMLDocumentFetcher.fetchString(from: pageURL, configuration: config)
        XCTAssertEqual(result, html)
    }

    func testImageDownloadServiceUsesInjectableSession() async throws {
        let imageURL = URL(string: "https://example.com/photo.jpg")!
        let payload = Data([0xFF, 0xD8, 0xFF, 0xD9])
        StubURLProtocol.setHandler { request in
            XCTAssertEqual(request.url, imageURL)
            let response = HTTPURLResponse(
                url: imageURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/jpeg"]
            )!
            return (response, payload)
        }

        var config = WebImagePickerConfiguration(allowedURLSchemes: ["https"])
        config.urlSession = urlSessionWithStub()

        let selection = try await ImageDownloadService.download(from: imageURL, configuration: config)
        XCTAssertEqual(selection.data, payload)
        XCTAssertEqual(selection.contentType, "image/jpeg")
        XCTAssertEqual(selection.sourceURL, imageURL)
    }
}
