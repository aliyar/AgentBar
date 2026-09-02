import OSLog
import AppKit
import Observation
import Sparkle

/// Sparkle-based auto-update. Scheduled checks use Sparkle's "gentle reminders": instead of a
/// window stealing focus, the app announces an available update in its own UI; user-initiated
/// checks (Settings → Check for Updates…) always show Sparkle's standard UI.
@Observable
final class UpdateController: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    /// User-defaults key that overrides the appcast URL (for testing against a local feed).
    nonisolated static let feedOverrideKey = "UpdateFeedURL"

    private(set) var availableVersion: String?
    private(set) var canCheckForUpdates = false
    private(set) var lastCheckDate: Date?
    private(set) var isStarted = false

    /// Fired when a scheduled check found an update and Sparkle was told not to show it.
    @ObservationIgnored var onUpdateAvailable: ((String) -> Void)?
    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
    }

    var updater: SPUUpdater { controller.updater }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    /// Sparkle refuses to verify an update without the EdDSA public key. The key is filled into
    /// Info.plist once the pair exists (docs/RELEASING.md); until then the updater stays off.
    var hasPublicKey: Bool {
        !(Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? "").isEmpty
    }

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    /// Starts Sparkle (never in tests, never without a public key). Safe to call once.
    func start() {
        guard !isStarted, !ProcessInfo.processInfo.isRunningTests else { return }
        guard hasPublicKey else {
            Log.updates.notice("updater not started: SUPublicEDKey is empty")
            return
        }
        isStarted = true
        controller.startUpdater()
        observations.append(updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
            let value = change.newValue ?? false
            Task { @MainActor in self?.canCheckForUpdates = value }
        })
        observations.append(updater.observe(\.lastUpdateCheckDate, options: [.initial, .new]) { [weak self] _, change in
            let value = change.newValue ?? nil
            Task { @MainActor in self?.lastCheckDate = value }
        })
        Log.updates.notice("updater started; feed=\(self.updater.feedURL?.absoluteString ?? "-", privacy: .public)")
    }

    /// Shows Sparkle's UI (also brings an already-found update into focus).
    func checkForUpdates() {
        guard isStarted else { return }
        AppActivation.activate()
        controller.checkForUpdates(nil)
    }

    // MARK: SPUUpdaterDelegate

    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        UserDefaults.standard.string(forKey: UpdateController.feedOverrideKey)
    }

    // MARK: SPUStandardUserDriverDelegate (gentle reminders)

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        // A menu bar app should never pop a window on its own: scheduled updates are announced
        // in the app's own UI, and the user brings up Sparkle's.
        false
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !handleShowingUpdate else { return }
        let version = update.displayVersionString
        MainActor.assumeIsolated {
            availableVersion = version
            onUpdateAvailable?(version)
        }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        MainActor.assumeIsolated { availableVersion = nil }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated { availableVersion = nil }
    }
}
