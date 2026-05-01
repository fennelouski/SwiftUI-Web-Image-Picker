//
//  DemoSampleCatalog.swift
//  SwiftUI Web Image Picker
//
//  Curated HTTPS URLs for the demo app only (hardcoded; no network fetch for the menu).
//

import Foundation
import WebImagePicker

enum DemoSampleCategory: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case encyclopedia = "Encyclopedia"
    case retail = "Retail & marketing"
    case news = "News"
    case community = "Community"
    case gallery = "Galleries"
    case vector = "SVG-heavy pages"
    case javaScript = "JavaScript (WebView)"
}

struct DemoSample: Identifiable {
    let id: String
    let category: DemoSampleCategory
    let title: String
    /// Short scenario blurb for the list UI and menu tooltips.
    let detail: String
    let urlString: String
    var extractionMode: WebImageExtractionMode = .staticHTML
}

enum DemoSampleCatalog {
    static let all: [DemoSample] = [
        DemoSample(
            id: "wiki-cat",
            category: .encyclopedia,
            title: "Wikipedia — Cat",
            detail: "Article photos, srcset, and many inline images (static HTML).",
            urlString: "https://en.wikipedia.org/wiki/Cat"
        ),
        DemoSample(
            id: "apple",
            category: .retail,
            title: "Apple",
            detail: "Marketing hero art and product imagery.",
            urlString: "https://www.apple.com/"
        ),
        DemoSample(
            id: "bbc",
            category: .news,
            title: "BBC",
            detail: "News layout with lead imagery.",
            urlString: "https://www.bbc.com/"
        ),
        DemoSample(
            id: "mozilla",
            category: .community,
            title: "Mozilla",
            detail: "Non-profit homepage with mixed imagery.",
            urlString: "https://www.mozilla.org/"
        ),
        DemoSample(
            id: "commons",
            category: .gallery,
            title: "Wikimedia Commons",
            detail: "Thumbnail-heavy main page and gallery patterns.",
            urlString: "https://commons.wikimedia.org/wiki/Main_Page"
        ),
        DemoSample(
            id: "mdn-svg",
            category: .vector,
            title: "MDN — SVG tutorial",
            detail: "Documentation with SVG examples embedded in HTML.",
            urlString: "https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial/Getting_Started"
        ),
        DemoSample(
            id: "unsplash-webview",
            category: .javaScript,
            title: "Unsplash (WebView)",
            detail: "Client-rendered gallery; demo uses `.webView` extraction.",
            urlString: "https://unsplash.com/",
            extractionMode: .webView
        ),
    ]

    static func samples(in category: DemoSampleCategory) -> [DemoSample] {
        all.filter { $0.category == category }
    }
}
