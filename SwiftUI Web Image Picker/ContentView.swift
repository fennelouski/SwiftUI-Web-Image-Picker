//
//  ContentView.swift
//  SwiftUI Web Image Picker
//
//  Created by Nathan Fennel on 5/1/26.
//

import SwiftUI
import WebImagePicker

struct ContentView: View {
    @State private var showPicker = false
    @State private var selections: [WebImageSelection] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button("Pick from web") {
                    showPicker = true
                }
                .buttonStyle(.borderedProminent)

                if selections.isEmpty {
                    Text("No images selected yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(selections.count) image(s) selected")
                        .font(.headline)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(selections.enumerated()), id: \.offset) { index, selection in
                                selectionRow(selection, index: index)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Web Image Picker")
        }
        .webImagePicker(isPresented: $showPicker, configuration: .init(selectionLimit: 5)) { newSelections in
            selections = newSelections
        }
    }

    @ViewBuilder
    private func selectionRow(_ selection: WebImageSelection, index: Int) -> some View {
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
