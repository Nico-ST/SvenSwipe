import Foundation

/// Singleton that persists the user's ad-toggle preference via UserDefaults.
/// Read / write from anywhere; SwiftUI views observe it via the published property.
final class AdSettings {
    static let shared = AdSettings()

    private static let key = "com.svenswipe.adsEnabled"

    /// `true` = ads are shown (default on first launch).
    var adsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.key) }
    }

    private init() {}
}
