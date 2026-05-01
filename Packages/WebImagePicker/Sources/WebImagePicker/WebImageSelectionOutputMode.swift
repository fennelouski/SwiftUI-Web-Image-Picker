import Foundation

/// How ``WebImagePicker`` builds ``WebImageSelection`` values passed to `onPick` after a download completes.
public enum WebImageSelectionOutputMode: Sendable, Hashable {
    /// Raw bytes in ``WebImageSelection/data`` (default). Same behavior as before this option existed.
    case dataOnly
    /// Ensures the payload decodes as a platform bitmap before completing; ``WebImageSelection/data`` still contains the bytes. Fails with ``WebImagePickerError/imageDecodeFailed`` if decoding is not possible.
    case platformImage
    /// Writes the payload to a unique file under the system temporary directory and sets ``WebImageSelection/temporaryFileURL``; ``WebImageSelection/data`` is empty to reduce memory use. The host should **copy or move** the file promptly and must not rely on it persisting; the system may delete temporary files at any time.
    case temporaryFileURL
}
