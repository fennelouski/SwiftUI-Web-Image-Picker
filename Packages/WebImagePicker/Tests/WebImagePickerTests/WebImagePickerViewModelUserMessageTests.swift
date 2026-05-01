import XCTest
@testable import WebImagePicker

@MainActor
final class WebImagePickerViewModelUserMessageTests: XCTestCase {
    func testUserMessageForEachWebImagePickerErrorCase() {
        let cases: [WebImagePickerError] = [
            .invalidURL,
            .invalidHTTPResponse,
            .htmlTooLarge,
            .htmlDecodingFailed,
            .extractionFailed,
            .noImagesFound,
            .imageTooLarge,
            .downloadFailed,
            .unsupportedImageType,
            .imageDecodeFailed,
        ]
        var seen = Set<String>()
        for err in cases {
            let message = WebImagePickerViewModel.userMessage(for: err)
            XCTAssertFalse(message.isEmpty, "Expected non-empty message for \(err)")
            seen.insert(message)
        }
        XCTAssertEqual(
            seen.count,
            cases.count,
            "Each error case should map to a distinct localized string in the default locale."
        )
    }

    func testUserMessageForUnknownErrorIsGeneric() {
        struct Mystery: Error {}
        let message = WebImagePickerViewModel.userMessage(for: Mystery())
        XCTAssertFalse(message.isEmpty)
    }
}
