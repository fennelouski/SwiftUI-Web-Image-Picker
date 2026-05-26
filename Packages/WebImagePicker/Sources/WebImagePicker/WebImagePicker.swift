import Foundation
import SwiftUI

// MARK: - Symbol chrome

private enum WebImagePickerSymbols {
    static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: WebImagePickerBundle.module)
    }

    static func symbolButton(
        systemName: String,
        accessibilityKey: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .accessibilityLabel(localized(accessibilityKey))
    }

    static var navigationTitle: some View {
        Image(systemName: "photo.on.rectangle.angled")
            .font(.headline)
            .accessibilityLabel(localized("webimage.navTitle"))
    }
}

/// A Photos-style flow for picking images discovered on a web page.
///
/// The picker loads a URL you provide, discovers image candidates (see ``WebImagePickerConfiguration/extractionMode``),
/// and presents them in a masonry grid. Use ``init(configuration:onCancel:onPick:)`` for full control over dismissal,
/// or ``View/webImagePicker(isPresented:configuration:onPick:)`` to present in a sheet that dismisses after a successful pick.
public struct WebImagePicker: View {
    private let configuration: WebImagePickerConfiguration
    private let onCancel: () -> Void
    private let onPick: ([WebImageSelection]) -> Void

    @State private var model: WebImagePickerViewModel
    @State private var didAttemptAutoLoad = false
    @State private var masonryContentHeight: CGFloat = 0

#if os(iOS) || os(tvOS) || os(visionOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    /// Creates a picker with configuration and completion handlers.
    /// - Parameters:
    ///   - configuration: Limits, timeouts, allowed schemes, and HTML vs. WebView extraction. Default is ``WebImagePickerConfiguration/default``.
    ///   - onCancel: Called when the user cancels (toolbar).
    ///   - onPick: Called with one or more ``WebImageSelection`` values after a successful pick.
    public init(
        configuration: WebImagePickerConfiguration = .default,
        onCancel: @escaping () -> Void,
        onPick: @escaping ([WebImageSelection]) -> Void
    ) {
        self.configuration = configuration
        self.onCancel = onCancel
        self.onPick = onPick
        _model = State(initialValue: WebImagePickerViewModel(configuration: configuration))
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .loadingPage where configuration.automaticallyLoadOnAppear && didAttemptAutoLoad:
                    autoLoadInProgressView
                case .urlEntry, .loadingPage:
                    urlEntryView
                case .browsing:
                    browsingView
                }
            }
            .navigationTitle("")
#if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    WebImagePickerSymbols.navigationTitle
                }
                ToolbarItem(placement: .cancellationAction) {
                    WebImagePickerSymbols.symbolButton(
                        systemName: "xmark",
                        accessibilityKey: "webimage.cancel",
                        action: onCancel
                    )
                }
                if model.phase == .browsing {
                    ToolbarItem(placement: .confirmationAction) {
                        WebImagePickerSymbols.symbolButton(
                            systemName: "checkmark",
                            accessibilityKey: "webimage.done"
                        ) {
                            Task { await confirmMultiSelection() }
                        }
                        .disabled(model.selectedURLs.isEmpty || model.isConfirming)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        WebImagePickerSymbols.symbolButton(
                            systemName: "arrow.uturn.backward",
                            accessibilityKey: "webimage.changeURL",
                            action: model.beginChangingURL
                        )
                    }
                }
            }
            .disabled(model.isConfirming)
            .overlay {
                if model.isConfirming {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView()
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .task {
                guard configuration.automaticallyLoadOnAppear else { return }
                guard !didAttemptAutoLoad else { return }
                guard model.phase == .urlEntry else { return }
                guard model.canStartLoad else { return }
                didAttemptAutoLoad = true
                await model.loadPage()
            }
        }
    }

    private var autoLoadInProgressView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(WebImagePickerSymbols.localized("webimage.loading"))
    }

    private var urlEntryView: some View {
        @Bindable var model = model
        return Form {
            Section {
                TextField(
                    String(localized: String.LocalizationValue("webimage.urlPlaceholder"), bundle: WebImagePickerBundle.module),
                    text: $model.urlString
                )
                    .textContentType(.URL)
#if os(iOS) || os(tvOS) || os(visionOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
#endif
#if os(macOS)
                    .textFieldStyle(.roundedBorder)
#endif
                Button {
                    Task { await model.loadPage() }
                } label: {
                    if model.phase == .loadingPage {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.down.circle")
                    }
                }
                .accessibilityLabel(
                    WebImagePickerSymbols.localized(
                        model.phase == .loadingPage ? "webimage.loading" : "webimage.loadPage"
                    )
                )
                .disabled(!model.canStartLoad)
            } footer: {
                if let message = model.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                } else {
                    Text(
                        String(localized: String.LocalizationValue("webimage.urlEntryFooter"), bundle: WebImagePickerBundle.module)
                    )
                }
            }

            if model.configuration.isMultiplePageEntryEnabled {
                Section {
                    ForEach($model.extraPageRows) { $row in
                        TextField(
                            String(localized: String.LocalizationValue("webimage.extraPagePlaceholder"), bundle: WebImagePickerBundle.module),
                            text: $row.text
                        )
                        .textContentType(.URL)
#if os(iOS) || os(tvOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
#endif
#if os(macOS)
                        .textFieldStyle(.roundedBorder)
#endif
                    }
                    .onDelete(perform: model.removeExtraPageRows)

                    Button {
                        model.addExtraPageRow()
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityLabel(WebImagePickerSymbols.localized("webimage.addPage"))
                } header: {
                    Label {
                        EmptyView()
                    } icon: {
                        Image(systemName: "doc.on.doc")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel(WebImagePickerSymbols.localized("webimage.additionalPagesSection"))
                } footer: {
                    Text(
                        String(localized: String.LocalizationValue("webimage.additionalPagesFooter"), bundle: WebImagePickerBundle.module)
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var browsingView: some View {
        @Bindable var model = model
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(
                        String(localized: String.LocalizationValue("webimage.searchPlaceholder"), bundle: WebImagePickerBundle.module),
                        text: $model.imageMetadataSearchQuery
                    )
#if os(iOS) || os(tvOS) || os(visionOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
#endif
#if os(macOS)
                    .textFieldStyle(.plain)
#endif
                }
#if os(macOS)
                .textFieldStyle(.roundedBorder)
#endif
                .accessibilityLabel(
                    String(localized: String.LocalizationValue("webimage.a11y.imageSearchField"), bundle: WebImagePickerBundle.module)
                )
                .accessibilityHint(
                    String(localized: String.LocalizationValue("webimage.a11y.imageSearchFieldHint"), bundle: WebImagePickerBundle.module)
                )
                .accessibilityIdentifier("webimage.imageMetadataSearch")

                if let notice = model.aggregationNotice {
                    Text(notice)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier("webimage.aggregationNotice")
                }
                if let httpSkip = model.httpSkippedImagesNotice {
                    Text(httpSkip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier("webimage.httpSkippedImagesNotice")
                }
                if let message = model.errorMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier("webimage.browsingDownloadError")
                }
                GeometryReader { geometry in
                    let imageCount = model.discoveredForDisplay.count
                    let baseColumns = platformBaseColumnCount
                    let columns = MasonryThumbnailScale.effectiveColumnCount(
                        baseColumns: baseColumns,
                        imageCount: imageCount
                    )
                    let minHeights = MasonryThumbnailScale.tileMinHeightsVsToday(imageCount: imageCount)
                    let maxTileWidth = MasonryThumbnailScale.maxTileWidth(
                        containerWidth: geometry.size.width,
                        baseColumns: baseColumns,
                        imageCount: imageCount
                    )
                    MasonryLayout(columns: columns, spacing: 8) {
                        ForEach(model.discoveredForDisplay) { item in
                            DiscoveredImageTile(
                                item: item,
                                selected: model.selectedURLs.contains(item.sourceURL),
                                maxTileWidth: maxTileWidth,
                                loadingMinHeight: minHeights.loading,
                                failureMinHeight: minHeights.failure,
                                onTap: {
                                    if configuration.selectionLimit == 1 {
                                        Task { await pickSingle(item) }
                                    } else {
                                        model.toggleSelection(item)
                                    }
                                }
                            )
                        }
                    }
                    .frame(width: geometry.size.width)
                    .background {
                        GeometryReader { contentGeometry in
                            Color.clear.preference(
                                key: MasonryHeightPreferenceKey.self,
                                value: contentGeometry.size.height
                            )
                        }
                    }
                }
                .onPreferenceChange(MasonryHeightPreferenceKey.self) { height in
                    masonryContentHeight = height
                }
                .frame(height: max(masonryContentHeight, masonryFallbackMinHeight(imageCount: model.discoveredForDisplay.count)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .bottom) {
            if configuration.selectionLimit > 1 {
                selectionSummaryView
            }
        }
    }

    private var selectionSummaryView: some View {
        let n = model.selectedURLs.count
        let limit = configuration.selectionLimit
        let accessibilityFormat = WebImagePickerSymbols.localized("webimage.a11y.selectionSummaryFormat")
        return HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .accessibilityHidden(true)
            Text("\(n)/\(limit)")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.bar)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String.localizedStringWithFormat(accessibilityFormat, n, limit))
    }

    private var platformBaseColumnCount: Int {
#if os(iOS) || os(tvOS) || os(visionOS)
        horizontalSizeClass == .regular ? 4 : 2
#elseif os(macOS)
        3
#else
        2
#endif
    }

    private func masonryFallbackMinHeight(imageCount: Int) -> CGFloat {
        guard imageCount > 0 else { return 0 }
        let scale = MasonryThumbnailScale.linearScaleVsToday(imageCount: imageCount)
        return MasonryThumbnailScale.todayLoadingMinHeight * scale
    }

    private func pickSingle(_ item: DiscoveredImage) async {
        model.errorMessage = nil
        model.isConfirming = true
        defer { model.isConfirming = false }
        do {
            let selection = try await ImageDownloadService.download(from: item.sourceURL, configuration: configuration)
            onPick([selection])
        } catch {
            model.errorMessage = WebImagePickerViewModel.userMessage(for: error)
        }
    }

    private func confirmMultiSelection() async {
        let urls = model.orderedSelection()
        guard !urls.isEmpty else { return }
        model.errorMessage = nil
        model.isConfirming = true
        defer { model.isConfirming = false }
        do {
            let selections = try await ImageDownloadService.downloadSelections(urls: urls, configuration: configuration)
            onPick(selections)
        } catch {
            model.errorMessage = WebImagePickerViewModel.userMessage(for: error)
        }
    }
}

// MARK: - Preference Key

private struct MasonryHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Tile

private struct DiscoveredImageTile: View {
    let item: DiscoveredImage
    let selected: Bool
    var maxTileWidth: CGFloat?
    var loadingMinHeight: CGFloat = MasonryThumbnailScale.todayLoadingMinHeight
    var failureMinHeight: CGFloat = MasonryThumbnailScale.todayFailureMinHeight
    let onTap: () -> Void

    var body: some View {
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
                    Color.secondary.opacity(0.12)
                        .frame(maxWidth: tileContentMaxWidth)
                        .frame(minHeight: failureMinHeight)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
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
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            item.accessibilityLabel
                ?? String(localized: String.LocalizationValue("webimage.a11y.imageFromWeb"), bundle: WebImagePickerBundle.module)
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var tileContentMaxWidth: CGFloat? {
        guard let maxTileWidth, maxTileWidth.isFinite, maxTileWidth > 0 else { return nil }
        return maxTileWidth
    }
}

// MARK: - View extension

public extension View {
    /// Presents ``WebImagePicker`` in a sheet and dismisses it after a successful pick.
    ///
    /// Cancel dismisses the sheet without calling `onPick`. On success, `onPick` receives the selections and the sheet is dismissed.
    /// - Parameters:
    ///   - isPresented: Controls sheet visibility.
    ///   - configuration: Behavior and network limits; defaults to ``WebImagePickerConfiguration/default``.
    ///   - onPick: Invoked with downloaded ``WebImageSelection`` values when the user confirms (or single-taps when the limit is 1).
    func webImagePicker(
        isPresented: Binding<Bool>,
        configuration: WebImagePickerConfiguration = .default,
        onPick: @escaping ([WebImageSelection]) -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            WebImagePicker(
                configuration: configuration,
                onCancel: { isPresented.wrappedValue = false },
                onPick: { selections in
                    onPick(selections)
                    isPresented.wrappedValue = false
                }
            )
        }
    }
}
