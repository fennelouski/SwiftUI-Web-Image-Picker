import SwiftUI

/// A Photos-style flow for picking images discovered on a web page.
public struct WebImagePicker: View {
    private let configuration: WebImagePickerConfiguration
    private let onCancel: () -> Void
    private let onPick: ([WebImageSelection]) -> Void

    @State private var model: WebImagePickerViewModel

#if os(iOS) || os(tvOS) || os(visionOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

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
                case .urlEntry, .loadingPage:
                    urlEntryView
                case .browsing:
                    browsingView
                }
            }
            .navigationTitle("Web images")
#if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                if model.phase == .browsing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            Task { await confirmMultiSelection() }
                        }
                        .disabled(model.selectedURLs.isEmpty || model.isConfirming)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Change URL", action: model.beginChangingURL)
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
        }
    }

    private var urlEntryView: some View {
        Form {
            Section {
                TextField("https://example.com", text: $model.urlString)
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
                            Text("Loading")
                        }
                    } else {
                        Text("Load page")
                    }
                }
                .disabled(model.phase == .loadingPage || model.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                if let message = model.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                } else {
                    Text("Paste a page URL. Images from the HTML response are shown (JavaScript-only images may be missing).")
                }
            }
        }
    }

    private var browsingView: some View {
        ScrollView {
            MasonryLayout(columns: masonryColumnCount, spacing: 8) {
                ForEach(model.discovered) { item in
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
        return "\(n) of \(limit) selected"
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
        .accessibilityLabel(item.accessibilityLabel ?? "Image from web")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - View extension

public extension View {
    /// Presents ``WebImagePicker`` in a sheet and dismisses it after a successful pick.
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
