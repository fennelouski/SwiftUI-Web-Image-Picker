import Foundation
import SwiftUI

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
            .navigationTitle(
                String(localized: String.LocalizationValue("webimage.navTitle"), bundle: WebImagePickerBundle.module)
            )
#if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        String(localized: String.LocalizationValue("webimage.cancel"), bundle: WebImagePickerBundle.module),
                        action: onCancel
                    )
                }
                if model.phase == .browsing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(
                            String(localized: String.LocalizationValue("webimage.done"), bundle: WebImagePickerBundle.module)
                        ) {
                            Task { await confirmMultiSelection() }
                        }
                        .disabled(model.selectedURLs.isEmpty || model.isConfirming)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(
                            String(localized: String.LocalizationValue("webimage.changeURL"), bundle: WebImagePickerBundle.module),
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
        VStack(spacing: 16) {
            ProgressView()
            Text(
                String(localized: String.LocalizationValue("webimage.loading"), bundle: WebImagePickerBundle.module)
            )
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        HStack {
                            ProgressView()
                            Text(
                                String(localized: String.LocalizationValue("webimage.loading"), bundle: WebImagePickerBundle.module)
                            )
                        }
                    } else {
                        Text(
                            String(localized: String.LocalizationValue("webimage.loadPage"), bundle: WebImagePickerBundle.module)
                        )
                    }
                }
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
                    Text(
                        String(localized: String.LocalizationValue("webimage.addPage"), bundle: WebImagePickerBundle.module)
                    )
                }
            } header: {
                Text(
                    String(localized: String.LocalizationValue("webimage.additionalPagesSection"), bundle: WebImagePickerBundle.module)
                )
            } footer: {
                Text(
                    String(localized: String.LocalizationValue("webimage.additionalPagesFooter"), bundle: WebImagePickerBundle.module)
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var browsingView: some View {
        @Bindable var model = model
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    String(localized: String.LocalizationValue("webimage.searchPlaceholder"), bundle: WebImagePickerBundle.module),
                    text: $model.imageMetadataSearchQuery
                )
#if os(iOS) || os(tvOS) || os(visionOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
#endif
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
                MasonryLayout(columns: masonryColumnCount, spacing: 8) {
                    ForEach(model.discoveredForDisplay) { item in
                        DiscoveredImageTile(
                            item: item,
                            selected: model.selectedURLs.contains(item.sourceURL),
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
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .bottom) {
            if configuration.selectionLimit > 1 {
                Text(selectionSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
    }

    private var selectionSummary: String {
        let n = model.selectedURLs.count
        let limit = configuration.selectionLimit
        let format = String(
            localized: String.LocalizationValue("webimage.selectionSummaryFormat"),
            bundle: WebImagePickerBundle.module
        )
        return String.localizedStringWithFormat(format, n, limit)
    }

    private var masonryColumnCount: Int {
#if os(iOS) || os(tvOS) || os(visionOS)
        horizontalSizeClass == .regular ? 4 : 2
#elseif os(macOS)
        3
#else
        2
#endif
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

// MARK: - Tile

private struct DiscoveredImageTile: View {
    let item: DiscoveredImage
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: item.sourceURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 120)
                        .background(Color.secondary.opacity(0.12))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                case .failure:
                    Color.secondary.opacity(0.12)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 100)
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
