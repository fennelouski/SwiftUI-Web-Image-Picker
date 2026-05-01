# Getting started with WebImagePicker

Present the picker from SwiftUI and handle downloaded selections.

## Overview

Use ``View/webImagePicker(isPresented:configuration:onPick:)`` for a sheet that dismisses after a successful pick, or embed ``WebImagePicker`` directly when you need custom dismissal with `onCancel` / `onPick`.

## Present with the view modifier

```swift
import SwiftUI
import WebImagePicker

struct ContentView: View {
    @State private var showPicker = false
    @State private var selections: [WebImageSelection] = []

    var body: some View {
        Button("Pick from web") { showPicker = true }
            .webImagePicker(isPresented: $showPicker) { newSelections in
                selections = newSelections
            }
    }
}
```

## Configure limits and extraction

Build a ``WebImagePickerConfiguration`` to cap selection count, tune network limits, restrict URL schemes, and choose ``WebImageExtractionMode`` (static HTML vs. WebView). Pass it into ``View/webImagePicker(isPresented:configuration:onPick:)`` or ``WebImagePicker/init(configuration:onCancel:onPick:)``.

## Use the selection

Each ``WebImageSelection`` exposes `data`, `contentType`, and `sourceURL`. On iOS, tvOS, or visionOS, call ``WebImageSelection/makeUIImage()``; on macOS, ``WebImageSelection/makeNSImage()``.
