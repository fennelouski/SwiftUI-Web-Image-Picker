import XCTest
@testable import WebImagePicker

#if os(macOS)
import AppKit
import SnapshotTesting
import SwiftUI

/// Lightweight visual regression for the initial URL-entry screen (macOS layout).
@MainActor
final class WebImagePickerSnapshotTests: XCTestCase {
    func testURLEntryLightMode() {
        let root = WebImagePicker(
            configuration: .default,
            onCancel: {},
            onPick: { _ in }
        )
        .environment(\.locale, Locale(identifier: "en_US"))
        .frame(width: 420, height: 520)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = CGRect(x: 0, y: 0, width: 420, height: 520)
        hosting.layoutSubtreeIfNeeded()

        assertSnapshot(
            of: hosting,
            as: .image(precision: 0.92, perceptualPrecision: 0.97),
            timeout: 15
        )
    }
}

#else

@MainActor
final class WebImagePickerSnapshotTests: XCTestCase {
    func testVisualRegressionUsesMacOSBaselines() throws {
        throw XCTSkip("Snapshot baselines are recorded and compared on macOS (see CONTRIBUTING.md).")
    }
}

#endif
