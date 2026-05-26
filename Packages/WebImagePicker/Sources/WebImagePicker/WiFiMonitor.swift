import Foundation
import Network

/// Tracks whether the device is on a non-expensive connection (WiFi / Ethernet)
/// so the picker can speculatively prefetch image discovery results.
final class WiFiMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "WebImagePicker.WiFiMonitor")
    private let lock = NSLock()
    private var _isOnWiFi = false

    /// `true` when the current network path is satisfied and not expensive
    /// (cellular and personal hotspot are considered expensive).
    var isOnWiFi: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isOnWiFi
    }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let nonExpensive = path.status == .satisfied && !path.isExpensive
            lock.lock()
            _isOnWiFi = nonExpensive
            lock.unlock()
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
