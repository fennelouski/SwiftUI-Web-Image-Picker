import SwiftUI

struct DiscoveredImageMetadataSheet: View {
    let item: DiscoveredImage
    let configuration: WebImagePickerConfiguration
    let recognizedText: String?
    let onDismiss: () -> Void

    @State private var probeResult: DiscoveredImageTileProbe.Result?
    @State private var isProbing = true

    var body: some View {
        NavigationStack {
            List {
                metadataRow(
                    labelKey: "webimage.tile.metadata.url",
                    value: item.sourceURL.absoluteString
                )
                metadataRow(
                    labelKey: "webimage.tile.metadata.alt",
                    value: item.accessibilityLabel
                )
                metadataRow(
                    labelKey: "webimage.tile.metadata.title",
                    value: item.title
                )
                if let recognizedText, !recognizedText.isEmpty {
                    metadataRow(
                        labelKey: "webimage.tile.metadata.recognizedText",
                        value: recognizedText
                    )
                }
                metadataRow(
                    labelKey: "webimage.tile.metadata.contentType",
                    value: probeResult?.contentType
                )
                metadataRow(
                    labelKey: "webimage.tile.metadata.dimensions",
                    value: dimensionsDisplay
                )
            }
            .navigationTitle(
                String(localized: String.LocalizationValue("webimage.tile.metadataTitle"), bundle: WebImagePickerBundle.module)
            )
#if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        String(localized: String.LocalizationValue("webimage.tile.done"), bundle: WebImagePickerBundle.module),
                        action: onDismiss
                    )
                }
            }
        }
        .task(id: item.sourceURL) {
            isProbing = true
            probeResult = await DiscoveredImageTileProbe.probe(url: item.sourceURL, configuration: configuration)
            isProbing = false
        }
    }

    private var dimensionsDisplay: String? {
        if isProbing {
            return String(localized: String.LocalizationValue("webimage.tile.metadata.loading"), bundle: WebImagePickerBundle.module)
        }
        guard let w = probeResult?.pixelWidth, let h = probeResult?.pixelHeight else {
            return String(localized: String.LocalizationValue("webimage.tile.metadata.unknown"), bundle: WebImagePickerBundle.module)
        }
        return "\(w) × \(h)"
    }

    @ViewBuilder
    private func metadataRow(labelKey: String, value: String?) -> some View {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = (trimmed?.isEmpty == false ? trimmed : nil)
            ?? String(localized: String.LocalizationValue("webimage.tile.metadata.unknown"), bundle: WebImagePickerBundle.module)
        LabeledContent(
            String(localized: String.LocalizationValue(labelKey), bundle: WebImagePickerBundle.module),
            value: display
        )
    }
}
