//
//  ContentView.swift
//  SwiftUI Web Image Picker
//
//  Demo integration: present `WebImagePicker` with `.webImagePicker(isPresented:configuration:onPick:)`.
//  Each presentation uses a fresh `WebImagePickerConfiguration` so `initialURLString` can pre-fill
//  the URL field when launching from a sample page (see `DemoSampleCatalog`).
//

import SwiftUI
import WebImagePicker

private enum DemoSymbols {
    static let pickFromWeb = "Pick from web"
    static let noSelection = "No images selected yet."
    static let selectionCountFormat = "%lld image(s) selected"
    static let navTitle = "Web Image Picker"
    static let trySamplePage = "Try a sample page"
    static let webView = "WebView"
}

struct ContentView: View {
    @State private var showPicker = false
    @State private var selections: [WebImageSelection] = []
    @State private var pickerConfiguration = WebImagePickerConfiguration()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button {
                    presentPickerBlank()
                } label: {
                    Image(systemName: "globe")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(DemoSymbols.pickFromWeb)

#if os(macOS)
                samplePagesMenuMacOS
#else
                samplePagesListNonMac
#endif

                if selections.isEmpty {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(DemoSymbols.noSelection)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .accessibilityHidden(true)
                        Text("\(selections.count)")
                            .font(.headline)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        String.localizedStringWithFormat(DemoSymbols.selectionCountFormat, selections.count)
                    )
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            // `WebImagePicker` completes with at most one row per `sourceURL` (selection is URL-deduped). If that ever changes, use an `Identifiable` wrapper with stable UUIDs instead of `id: \.sourceURL`.
                            ForEach(selections, id: \.sourceURL) { selection in
                                selectionRow(selection)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.headline)
                        .accessibilityLabel(DemoSymbols.navTitle)
                }
            }
        }
        .webImagePicker(isPresented: $showPicker, configuration: pickerConfiguration) { newSelections in
            selections = newSelections
        }
    }

#if os(macOS)
    private var samplePagesMenuMacOS: some View {
        Menu {
            ForEach(DemoSampleCategory.allCases) { category in
                Menu(category.rawValue) {
                    ForEach(DemoSampleCatalog.samples(in: category)) { sample in
                        Button(sample.title) {
                            presentPicker(sample: sample)
                        }
                        .help(sample.detail)
                    }
                }
            }
        } label: {
            Label(DemoSymbols.trySamplePage, systemImage: "book.pages")
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel(DemoSymbols.trySamplePage)
    }
#else
    private var samplePagesListNonMac: some View {
        List {
            ForEach(DemoSampleCategory.allCases) { category in
                Section(category.rawValue) {
                    ForEach(DemoSampleCatalog.samples(in: category)) { sample in
                        Button {
                            presentPicker(sample: sample)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(sample.title)
                                    if sample.extractionMode == .webView {
                                        Image(systemName: "safari")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.secondary.opacity(0.2))
                                            .clipShape(Capsule())
                                            .accessibilityLabel(DemoSymbols.webView)
                                    }
                                }
                                Text(sample.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .frame(minHeight: 220, maxHeight: 360)
    }
#endif

    private func presentPickerBlank() {
        pickerConfiguration = WebImagePickerConfiguration()
        showPicker = true
    }

    private func presentPicker(sample: DemoSample) {
        var config = WebImagePickerConfiguration(initialURLString: sample.urlString)
        config.extractionMode = sample.extractionMode
        pickerConfiguration = config
        showPicker = true
    }

    @ViewBuilder
    private func selectionRow(_ selection: WebImageSelection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selection.sourceURL.absoluteString)
                .font(.caption)
                .lineLimit(2)
                .textSelection(.enabled)
#if os(macOS)
            if let image = selection.makeNSImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
#elseif canImport(UIKit)
            if let image = selection.makeUIImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
#endif
            if let type = selection.contentType {
                Text(type)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("\(selection.data.count) bytes")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
