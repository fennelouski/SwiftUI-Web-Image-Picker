import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

struct DiscoveredImagePreviewSheet: View {
    let item: DiscoveredImage
    let configuration: WebImagePickerConfiguration
    let onDismiss: () -> Void

    @State private var downloadedSelection: WebImageSelection?
    @State private var isLoadingDownload = false

    var body: some View {
        NavigationStack {
            ScrollView {
                previewImage
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .navigationTitle(
                String(localized: String.LocalizationValue("webimage.tile.previewTitle"), bundle: WebImagePickerBundle.module)
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
            await loadFullImageIfNeeded()
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        if let selection = downloadedSelection, let platformView = platformImageView(from: selection) {
            platformView
                .scaledToFit()
                .frame(maxHeight: previewMaxHeight)
        } else {
            AsyncImage(url: item.sourceURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(minHeight: 200)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: previewMaxHeight)
                case .failure:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 200)
                @unknown default:
                    EmptyView()
                }
            }
            .overlay {
                if isLoadingDownload {
                    ProgressView()
                }
            }
        }
    }

    private var previewMaxHeight: CGFloat {
#if os(iOS)
        UIScreen.main.bounds.height * 0.7
#else
        560
#endif
    }

    @ViewBuilder
    private func platformImageView(from selection: WebImageSelection) -> Image? {
#if canImport(UIKit)
        if let ui = selection.makeUIImage() {
            Image(uiImage: ui)
        }
#elseif os(macOS)
        if let ns = selection.makeNSImage() {
            Image(nsImage: ns)
        }
#else
        nil
#endif
    }

    private func loadFullImageIfNeeded() async {
        isLoadingDownload = true
        defer { isLoadingDownload = false }
        do {
            let selection = try await DiscoveredImageTileActionHandler.downloadForPreview(
                item: item,
                configuration: configuration
            )
            downloadedSelection = selection
        } catch {
            downloadedSelection = nil
        }
    }
}
