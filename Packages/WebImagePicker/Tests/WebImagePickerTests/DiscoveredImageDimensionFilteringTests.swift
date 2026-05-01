import CoreGraphics
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

final class DiscoveredImageDimensionFilteringTests: XCTestCase {
    private var dim1x1: Data!
    private var dim40x30: Data!

    override func setUp() {
        super.setUp()
        let bundle = Bundle.module
        let u1 = bundle.url(forResource: "dim-1x1", withExtension: "png", subdirectory: "Fixtures")!
        let u2 = bundle.url(forResource: "dim-40x30", withExtension: "png", subdirectory: "Fixtures")!
        dim1x1 = try! Data(contentsOf: u1)
        dim40x30 = try! Data(contentsOf: u2)
    }

    override func tearDown() {
        StubURLProtocol.setHandler(nil)
        dim1x1 = nil
        dim40x30 = nil
        super.tearDown()
    }

    func testReadsPNGDimensionsFromFixture() {
        XCTAssertEqual(ImagePixelDimensions.read(from: dim1x1)?.width, 1)
        XCTAssertEqual(ImagePixelDimensions.read(from: dim1x1)?.height, 1)
        XCTAssertEqual(ImagePixelDimensions.read(from: dim40x30)?.width, 40)
        XCTAssertEqual(ImagePixelDimensions.read(from: dim40x30)?.height, 30)
    }

    func testPassesBoundsMinimumAndMaximum() {
        var config = WebImagePickerConfiguration.default
        config.minimumImageDimensions = CGSize(width: 10, height: 10)
        XCTAssertTrue(DiscoveredImageDimensionFiltering.passesBounds(width: 10, height: 10, configuration: config))
        XCTAssertFalse(DiscoveredImageDimensionFiltering.passesBounds(width: 9, height: 10, configuration: config))

        config = WebImagePickerConfiguration.default
        config.maximumImageDimensions = CGSize(width: 20, height: 20)
        XCTAssertTrue(DiscoveredImageDimensionFiltering.passesBounds(width: 20, height: 20, configuration: config))
        XCTAssertFalse(DiscoveredImageDimensionFiltering.passesBounds(width: 21, height: 20, configuration: config))
    }

    func testPassesBoundsZeroAxisMeansUnconstrained() {
        var config = WebImagePickerConfiguration.default
        config.minimumImageDimensions = CGSize(width: 100, height: 0)
        XCTAssertTrue(DiscoveredImageDimensionFiltering.passesBounds(width: 100, height: 1, configuration: config))
        XCTAssertFalse(DiscoveredImageDimensionFiltering.passesBounds(width: 10, height: 1, configuration: config))

        config = WebImagePickerConfiguration.default
        config.maximumImageDimensions = CGSize(width: 0, height: 10)
        XCTAssertTrue(DiscoveredImageDimensionFiltering.passesBounds(width: 999, height: 10, configuration: config))
        XCTAssertFalse(DiscoveredImageDimensionFiltering.passesBounds(width: 999, height: 11, configuration: config))
    }

    func testAggregationDropsImagesBelowMinimumViaStubSession() async throws {
        let page = URL(string: "https://page.example/")!
        let small = URL(string: "https://cdn.example/small.png")!
        let big = URL(string: "https://cdn.example/big.png")!

        let oneByOne = try XCTUnwrap(dim1x1)
        let fortyByThirty = try XCTUnwrap(dim40x30)
        StubURLProtocol.setHandler { request in
            let url = try XCTUnwrap(request.url)
            let payload: Data
            if url == small {
                payload = oneByOne
            } else if url == big {
                payload = fortyByThirty
            } else {
                payload = Data()
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 206,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/png"]
            )!
            return (response, payload)
        }

        var config = WebImagePickerConfiguration.default
        config.minimumImageDimensions = CGSize(width: 5, height: 5)
        config.urlSession = urlSessionWithStub()

        let extractor = MockPageImageExtractor(pageResults: [
            page: .success([
                DiscoveredImage(sourceURL: small, accessibilityLabel: nil),
                DiscoveredImage(sourceURL: big, accessibilityLabel: nil),
            ]),
        ])

        let merge = await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: [page],
            configuration: config,
            extractor: extractor
        )

        XCTAssertTrue(merge.failedPageURLs.isEmpty)
        XCTAssertEqual(merge.images.map(\.sourceURL), [big])
    }

    func testProbeFailureKeepsCandidate() async throws {
        let page = URL(string: "https://page.example/")!
        let img = URL(string: "https://cdn.example/mystery.png")!

        StubURLProtocol.setHandler { _ in
            throw URLError(.notConnectedToInternet)
        }

        var config = WebImagePickerConfiguration.default
        config.minimumImageDimensions = CGSize(width: 50, height: 50)
        config.urlSession = urlSessionWithStub()

        let extractor = MockPageImageExtractor(pageResults: [
            page: .success([DiscoveredImage(sourceURL: img, accessibilityLabel: nil)]),
        ])

        let merge = await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: [page],
            configuration: config,
            extractor: extractor
        )

        XCTAssertEqual(merge.images.count, 1)
        XCTAssertEqual(merge.images.first?.sourceURL, img)
    }

    func testFilterRunsBeforePerPageCap() async throws {
        let page = URL(string: "https://page.example/")!
        let a = URL(string: "https://cdn.example/a.png")!
        let b = URL(string: "https://cdn.example/b.png")!
        let c = URL(string: "https://cdn.example/c.png")!

        let oneByOne = try XCTUnwrap(dim1x1)
        let fortyByThirty = try XCTUnwrap(dim40x30)
        StubURLProtocol.setHandler { request in
            let url = try XCTUnwrap(request.url)
            let payload = url == c ? oneByOne : fortyByThirty
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, payload)
        }

        var config = WebImagePickerConfiguration.default
        config.minimumImageDimensions = CGSize(width: 10, height: 10)
        config.maximumDiscoveredImagesPerPage = 1
        config.urlSession = urlSessionWithStub()

        let extractor = MockPageImageExtractor(pageResults: [
            page: .success([
                DiscoveredImage(sourceURL: a, accessibilityLabel: nil),
                DiscoveredImage(sourceURL: b, accessibilityLabel: nil),
                DiscoveredImage(sourceURL: c, accessibilityLabel: nil),
            ]),
        ])

        let merge = await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: [page],
            configuration: config,
            extractor: extractor
        )

        XCTAssertEqual(merge.images.count, 1)
        XCTAssertEqual(merge.images.first?.sourceURL, a)
    }
}

private struct MockPageImageExtractor: PageImageExtractor {
    var pageResults: [URL: Result<[DiscoveredImage], Error>]
    private static let missing = NSError(domain: "test", code: 0)

    func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage] {
        guard let result = pageResults[pageURL] else {
            throw Self.missing
        }
        return try result.get()
    }
}
