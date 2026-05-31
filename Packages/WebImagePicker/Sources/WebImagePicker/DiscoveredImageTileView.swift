import SwiftUI

struct DiscoveredImageTileView: View {
    let item: DiscoveredImage
    let selected: Bool
    var maxTileWidth: CGFloat?
    var loadingMinHeight: CGFloat = MasonryThumbnailScale.todayLoadingMinHeight
    var failureMinHeight: CGFloat = MasonryThumbnailScale.todayFailureMinHeight
    let configuration: WebImagePickerConfiguration
    let recognizedText: String?
    let onTap: () -> Void
    let onActionError: (String) -> Void

    @State private var isActionInProgress = false
    @State private var activeSheet: TileSheetKind?

    private enum TileSheetKind: Identifiable {
        case preview
        case metadata

        var id: String {
            switch self {
            case .preview: "preview"
            case .metadata: "metadata"
            }
        }
    }

    private var contextMenuConfig: WebImageTileContextMenuConfiguration {
        configuration.imageTileContextMenu
    }

    private var menuEntries: [DiscoveredImageTileMenuEntry] {
        DiscoveredImageTileContextMenuBuilder.menuEntries(config: contextMenuConfig)
    }

    var body: some View {
        tileContent
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .modifier(TileContextMenuModifier(
                entries: menuEntries,
                groupedEntries: DiscoveredImageTileContextMenuBuilder.groupedClipboardEntries(config: contextMenuConfig),
                onEntry: performMenuEntry
            ))
            .sheet(item: $activeSheet) { kind in
                sheetContent(for: kind)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                item.accessibilityLabel
                    ?? String(localized: String.LocalizationValue("webimage.a11y.imageFromWeb"), bundle: WebImagePickerBundle.module)
            )
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var tileContent: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: item.sourceURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: tileContentMaxWidth, alignment: .center)
                        .frame(minHeight: loadingMinHeight)
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.12))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: tileContentMaxWidth)
                        .frame(maxWidth: .infinity)
                case .failure:
                    EmptyView()
                        .frame(width: 0, height: 0)
                @unknown default:
                    EmptyView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(6)
                    .shadow(radius: 2)
            }

            if isActionInProgress {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.black.opacity(0.35))
                ProgressView()
                    .tint(.white)
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for kind: TileSheetKind) -> some View {
        switch kind {
        case .preview:
            DiscoveredImagePreviewSheet(
                item: item,
                configuration: configuration,
                onDismiss: { activeSheet = nil }
            )
        case .metadata:
            DiscoveredImageMetadataSheet(
                item: item,
                configuration: configuration,
                recognizedText: recognizedText,
                onDismiss: { activeSheet = nil }
            )
        }
    }

    private var tileContentMaxWidth: CGFloat? {
        guard let maxTileWidth, maxTileWidth.isFinite, maxTileWidth > 0 else { return nil }
        return maxTileWidth
    }

    private func performMenuEntry(_ entry: DiscoveredImageTileMenuEntry) {
        switch entry {
        case .copyImageURL:
            DiscoveredImageTileActionHandler.copyImageURL(item)
        case .preview:
            activeSheet = .preview
        case .showMetadata:
            activeSheet = .metadata
        case .copyImage:
            runAsyncAction {
                try await DiscoveredImageTileActionHandler.copyImage(item: item, configuration: configuration)
            }
        case .liftSubject:
            runAsyncAction {
                try await DiscoveredImageTileActionHandler.liftSubject(item: item, configuration: configuration)
            }
        case .groupedClipboardActions:
            break
        }
    }

    private func runAsyncAction(_ operation: @escaping () async throws -> Void) {
        guard !isActionInProgress else { return }
        isActionInProgress = true
        Task {
            defer { isActionInProgress = false }
            do {
                try await operation()
            } catch {
                onActionError(WebImagePickerViewModel.userMessage(for: error))
            }
        }
    }
}

// MARK: - Context menu

private struct TileContextMenuModifier: ViewModifier {
    let entries: [DiscoveredImageTileMenuEntry]
    let groupedEntries: [DiscoveredImageTileMenuEntry]
    let onEntry: (DiscoveredImageTileMenuEntry) -> Void

    func body(content: Content) -> some View {
        if entries.isEmpty {
            content
        } else {
            content.contextMenu {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    if entry == .groupedClipboardActions {
                        Menu {
                            ForEach(Array(groupedEntries.enumerated()), id: \.offset) { _, sub in
                                menuButton(for: sub)
                            }
                        } label: {
                            Label(
                                localized("webimage.tile.imageActions"),
                                systemImage: "ellipsis.circle"
                            )
                        }
                    } else {
                        menuButton(for: entry)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func menuButton(for entry: DiscoveredImageTileMenuEntry) -> some View {
        Button {
            onEntry(entry)
        } label: {
            Label(localized(labelKey(for: entry)), systemImage: systemImage(for: entry))
        }
    }

    private func labelKey(for entry: DiscoveredImageTileMenuEntry) -> String {
        switch entry {
        case .copyImage: "webimage.tile.copyImage"
        case .copyImageURL: "webimage.tile.copyImageURL"
        case .liftSubject: "webimage.tile.liftSubject"
        case .groupedClipboardActions: "webimage.tile.imageActions"
        case .preview: "webimage.tile.preview"
        case .showMetadata: "webimage.tile.metadata"
        }
    }

    private func systemImage(for entry: DiscoveredImageTileMenuEntry) -> String {
        switch entry {
        case .copyImage: "doc.on.doc"
        case .copyImageURL: "link"
        case .liftSubject: "person.crop.rectangle"
        case .groupedClipboardActions: "ellipsis.circle"
        case .preview: "arrow.up.left.and.arrow.down.right"
        case .showMetadata: "info.circle"
        }
    }

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: WebImagePickerBundle.module)
    }
}
