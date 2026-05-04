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

Build a ``WebImagePickerConfiguration`` to tune selection count (default **1** for single-tap pick; raise the limit for multi-select), network limits, URL schemes, and ``WebImageExtractionMode`` (static HTML vs. WebView). Pass it into ``View/webImagePicker(isPresented:configuration:onPick:)`` or ``WebImagePicker/init(configuration:onCancel:onPick:)``. Set ``WebImagePickerConfiguration/automaticallyLoadOnAppear`` to `true` together with ``WebImagePickerConfiguration/initialURLString`` (or ``WebImagePickerConfiguration/additionalPageURLs``) to skip the manual “Load page” tap when the picker opens.

### HTTPS, optional HTTP, and App Transport Security

By default, ``WebImagePickerConfiguration/allowedURLSchemes`` is **HTTPS only** for both **page** URLs and **discovered image** URLs. If the user enters an `http:` page URL, the picker shows a clear error instead of a generic failure. If an HTTPS page references `http:` images and HTTP is not allowed, those images are omitted and a notice explains how many were skipped.

To allow cleartext `http:` for pages and images, include `"http"` in ``WebImagePickerConfiguration/allowedURLSchemes`` or use ``WebImagePickerConfiguration/allowingHTTPAndHTTPS(basedOn:)`` (see also ``WebImagePickerConfiguration/httpsOnly`` as an alias for the default).

On Apple platforms, loading HTTP still requires the **host app** to satisfy [App Transport Security](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity): for example per-domain exceptions under `NSExceptionDomains`, or `NSAllowsArbitraryLoads` (broad and usually discouraged). The package does not change ATS for you.

## Use the selection

Each ``WebImageSelection`` exposes `data`, `contentType`, and `sourceURL`. On iOS, tvOS, or visionOS, call ``WebImageSelection/makeUIImage()``; on macOS, ``WebImageSelection/makeNSImage()``.

## Runnable demo in this repository

The **SwiftUI Web Image Picker** app at the root of [the package repository](https://github.com/fennelouski/SwiftUI-Web-Image-Picker) is the recommended place to experiment. Open `SwiftUI Web Image Picker.xcodeproj`, run the **SwiftUI Web Image Picker** scheme, and use **Pick from web** or the sample-page menu. The README **Quick try** section has step-by-step setup (including signing).
