//
//  ContentView.swift
//  SwiftUI Web Image Picker
//
//  Demo integration: present `WebImagePicker` with `.webImagePicker(isPresented:configuration:onPick:)`.
//  Each presentation uses a fresh `WebImagePickerConfiguration` so `initialURLString` can pre-fill
//  the URL field when launching from a sample page.
//

import SwiftUI
import WebImagePicker

struct ContentView: View {
    @State private var showPicker = false
    @State private var selections: [WebImageSelection] = []
    @State private var pickerConfiguration = WebImagePickerConfiguration()

    /// Static HTML–heavy pages that work well with default `.staticHTML` extraction.
    private enum SamplePage: String, CaseIterable {
        case wikipediaCat = "https://en.wikipedia.org/wiki/Cat"
        case apple = "https://www.apple.com/"
        case mozilla = "https://www.mozilla.org/"

        var menuTitle: String {
            switch self {
            case .wikipediaCat: "Wikipedia — Cat"
            case .apple: "Apple.com"
            case .mozilla: "Mozilla.org"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button("Pick from web") {
                    presentPicker(initialURL: nil)
                }
                .buttonStyle(.borderedProminent)

                Menu("Try a sample page") {
                    ForEach(SamplePage.allCases, id: \.self) { page in
                        Button(page.menuTitle) {
                            presentPicker(initialURL: page.rawValue)
                        }
                    }
                }

                if selections.isEmpty {
                    Text("No images selected yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(selections.count) image(s) selected")
                        .font(.headline)
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
            .navigationTitle("Web Image Picker")
        }
        .webImagePicker(isPresented: $showPicker, configuration: pickerConfiguration) { newSelections in
            selections = newSelections
        }
    }

    private func presentPicker(initialURL: String?) {
        pickerConfiguration = WebImagePickerConfiguration(initialURLString: initialURL)
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
