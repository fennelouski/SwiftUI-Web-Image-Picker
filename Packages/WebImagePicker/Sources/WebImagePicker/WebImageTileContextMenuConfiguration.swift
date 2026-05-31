import Foundation

/// Actions available from a long-press or right-click context menu on a browsing-grid image tile.
public struct WebImageTileContextMenuAction: OptionSet, Sendable, Hashable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// Download the image and copy it to the system pasteboard.
    public static let copyImage = WebImageTileContextMenuAction(rawValue: 1 << 0)

    /// Copy the discovered image URL string to the pasteboard.
    public static let copyImageURL = WebImageTileContextMenuAction(rawValue: 1 << 1)

    /// Run on-device subject isolation and copy a transparent PNG to the pasteboard (iOS and macOS only).
    public static let liftSubject = WebImageTileContextMenuAction(rawValue: 1 << 2)

    /// Present a larger in-picker preview sheet (does not complete selection).
    public static let preview = WebImageTileContextMenuAction(rawValue: 1 << 3)

    /// Present a sheet with discovery metadata and optional probed dimensions.
    public static let showMetadata = WebImageTileContextMenuAction(rawValue: 1 << 4)

    /// Clipboard-related actions (copy image, URL, lift subject).
    public static let clipboardActions: WebImageTileContextMenuAction = [.copyImage, .copyImageURL, .liftSubject]
}

/// How copy / URL / lift actions appear in the tile context menu.
public enum WebImageTileClipboardPresentation: Sendable, Hashable {
    /// Each enabled clipboard action is its own context-menu row.
    case separateMenuItems

    /// One context-menu row opens a picker among the enabled clipboard actions.
    case groupedPicker
}

/// Secondary interactions on grid tiles during browsing (long-press on iOS, right-click on macOS).
///
/// Default is disabled so existing apps keep tap-only behavior. When enabled, actions may trigger
/// additional image downloads subject to ``WebImagePickerConfiguration/maximumImageDownloadBytes``.
public struct WebImageTileContextMenuConfiguration: Sendable, Hashable {
    /// When `false`, no context menu is shown regardless of ``actions``. Default `false`.
    public var isEnabled: Bool

    /// Which menu actions are available. Default empty.
    public var actions: WebImageTileContextMenuAction

    /// Layout for ``WebImageTileContextMenuAction/clipboardActions``. Default ``separateMenuItems``.
    public var clipboardPresentation: WebImageTileClipboardPresentation

    public init(
        isEnabled: Bool = false,
        actions: WebImageTileContextMenuAction = [],
        clipboardPresentation: WebImageTileClipboardPresentation = .separateMenuItems
    ) {
        self.isEnabled = isEnabled
        self.actions = actions
        self.clipboardPresentation = clipboardPresentation
    }

    public static let disabled = WebImageTileContextMenuConfiguration()
}
