import XCTest
@testable import WebImagePicker

@MainActor
final class WebImagePickerViewModelInitialURLTests: XCTestCase {
    func testInitialURLStringPreFillsField() {
        let config = WebImagePickerConfiguration(initialURLString: "  https://example.com/path  ")
        let model = WebImagePickerViewModel(configuration: config)
        XCTAssertEqual(model.urlString, "https://example.com/path")
    }

    func testNilInitialURLStringLeavesFieldEmpty() {
        let model = WebImagePickerViewModel(configuration: .default)
        XCTAssertTrue(model.urlString.isEmpty)
    }

    func testWhitespaceOnlyInitialURLStringLeavesFieldEmpty() {
        let config = WebImagePickerConfiguration(initialURLString: "   \n")
        let model = WebImagePickerViewModel(configuration: config)
        XCTAssertTrue(model.urlString.isEmpty)
    }
}
