// swift-tools-version: 5.9
// SPDX-License-Identifier: MPL-2.0
// Canonical manifest for URL-based SPM; keep in sync with Packages/WebImagePicker/Package.swift.
import PackageDescription

let package = Package(
    name: "WebImagePicker",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "WebImagePicker", targets: ["WebImagePicker"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "WebImagePicker",
            dependencies: ["SwiftSoup"],
            path: "Packages/WebImagePicker/Sources/WebImagePicker",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "WebImagePickerTests",
            dependencies: [
                "WebImagePicker",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Packages/WebImagePicker/Tests/WebImagePickerTests",
            exclude: ["__Snapshots__"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
