import XCTest
@testable import WebImagePicker

final class WebImagePickerLocalizationTests: XCTestCase {
    func testBundledSpanishDiffersFromEnglishForSharedKey() throws {
        let bundle = WebImagePickerBundle.module
        let enBundle = try XCTUnwrap(Bundle(path: try XCTUnwrap(bundle.path(forResource: "en", ofType: "lproj"))))
        let esBundle = try XCTUnwrap(Bundle(path: try XCTUnwrap(bundle.path(forResource: "es", ofType: "lproj"))))

        let en = String(localized: String.LocalizationValue("webimage.cancel"), bundle: enBundle)
        let es = String(localized: String.LocalizationValue("webimage.cancel"), bundle: esBundle)

        XCTAssertEqual(en, "Cancel")
        XCTAssertEqual(es, "Cancelar")
        XCTAssertNotEqual(en, es)
    }
}
