import Foundation

/// Describes one row in a tile context menu (pure logic for testing).
enum DiscoveredImageTileMenuEntry: Equatable, Sendable {
    case copyImage
    case copyImageURL
    case liftSubject
    case groupedClipboardActions
    case preview
    case showMetadata
}

enum DiscoveredImageTileContextMenuBuilder {
    /// Whether lift subject can appear on this platform.
    static var isLiftSubjectSupported: Bool {
#if os(iOS) || os(macOS)
        return DiscoveredImageSubjectLiftService.isSupported
#else
        return false
#endif
    }

    static func effectiveActions(
        from config: WebImageTileContextMenuConfiguration
    ) -> WebImageTileContextMenuAction {
        guard config.isEnabled else { return [] }
        var actions = config.actions
        if !isLiftSubjectSupported {
            actions.subtract(.liftSubject)
        }
        return actions
    }

    static func menuEntries(
        config: WebImageTileContextMenuConfiguration
    ) -> [DiscoveredImageTileMenuEntry] {
        let actions = effectiveActions(from: config)
        guard !actions.isEmpty else { return [] }

        var entries: [DiscoveredImageTileMenuEntry] = []
        let clipboard = actions.intersection(.clipboardActions)
        if !clipboard.isEmpty {
            switch config.clipboardPresentation {
            case .separateMenuItems:
                if actions.contains(.copyImage) { entries.append(.copyImage) }
                if actions.contains(.copyImageURL) { entries.append(.copyImageURL) }
                if actions.contains(.liftSubject) { entries.append(.liftSubject) }
            case .groupedPicker:
                entries.append(.groupedClipboardActions)
            }
        }
        if actions.contains(.preview) { entries.append(.preview) }
        if actions.contains(.showMetadata) { entries.append(.showMetadata) }
        return entries
    }

    static func groupedClipboardEntries(
        config: WebImageTileContextMenuConfiguration
    ) -> [DiscoveredImageTileMenuEntry] {
        let actions = effectiveActions(from: config)
        var entries: [DiscoveredImageTileMenuEntry] = []
        if actions.contains(.copyImage) { entries.append(.copyImage) }
        if actions.contains(.copyImageURL) { entries.append(.copyImageURL) }
        if actions.contains(.liftSubject) { entries.append(.liftSubject) }
        return entries
    }
}
