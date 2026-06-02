import Foundation

/// Controls how aggressively ``PageURLCorrection`` rewrites hosts and TLDs after a failed page load.
public enum SmartURLFallbackTLDStrategy: String, Sendable, Hashable {
    /// Reserved for future use; currently behaves like ``moderate``.
    case conservative

    /// Reserved for future use; currently behaves like ``aggressive`` with a smaller TLD list.
    case moderate

    /// Try multiple TLD variants, locale ccTLD, and optional `www.` prefixes.
    case aggressive
}
