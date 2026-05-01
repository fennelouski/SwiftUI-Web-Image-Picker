// swift-tools-version: 5.9
// SPDX-License-Identifier: MPL-2.0
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
    ],
    targets: [
        .target(
            name: "WebImagePicker",
            dependencies: ["SwiftSoup"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "WebImagePickerTests",
            dependencies: ["WebImagePicker"],
            path: "Tests/WebImagePickerTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
