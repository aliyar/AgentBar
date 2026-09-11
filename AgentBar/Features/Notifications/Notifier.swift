import AppKit
import Foundation
import OSLog
import UserNotifications
import AgentBarKit

/// Says one short thing when something the user asked to hear about happens: a service
/// goes down or comes back, or a window's use reaches one of the marks they chose.
///
/// For a service the second message is the one the feature exists for. A status page can
/// tell you a service is down; nothing tells you it is working again, so you go back and
/// try until it does. Each message is a few words and no buttons - there is nothing to
/// decide, only something to know.
///
/// No entitlement is needed: the app is not sandboxed and is signed with a Developer ID.
/// Permission is asked the first time the user turns one of the switches on, never at
/// launch - a menu bar app that asks for notifications before it has anything to say is
/// asking about a feature the user has not met yet.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter?
    private var authorization: Task<Bool, Never>?

    /// What clicking a message does. Set by `AppDependencies`; the notifier knows nothing
    /// about windows.
    var onOpen: (() -> Void)?

    /// True while notifications can be posted at all. False under tests and in any host
    /// that is not a real app bundle, where the notification centre is unusable.
    static var isAvailable: Bool {
        !ProcessInfo.processInfo.isRunningTests && Bundle.main.bundleURL.pathExtension == "app"
    }

    override init() {
        center = Self.isAvailable ? .current() : nil
        super.init()
        center?.delegate = self
    }

    // MARK: What a message does

    /// The app has no windows of its own most of the time, so a message must show even
    /// while it is the active app - otherwise turning to it swallows its own news.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Clicking one opens the panel, where the row it is about says the rest.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        await MainActor.run { self.onOpen?() }
    }

    /// Asks macOS once, and remembers the answer for the rest of the launch. Called when a
    /// switch is turned on, and before the first message either way - a user who allowed
    /// them in System Settings after refusing here should not have to toggle anything.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard let center else { return false }
        if let authorization { return await authorization.value }
        let task = Task { () -> Bool in
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                Log.app.notice("notifications refused: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
        authorization = task
        return await task.value
    }

    /// Whether macOS will show anything at all, so Settings can say so rather than leaving
    /// a switch that quietly does nothing.
    func isAllowed() async -> Bool {
        guard let center else { return false }
        return await center.notificationSettings().authorizationStatus == .authorized
    }

    func post(_ transition: StatusWatch.Transition, for agent: Agent, status: ServiceStatus) {
        guard center != nil else { return }
        let title: String, body: String
        switch transition {
        case .wentDown(let level):
            title = "\(agent.title) is down"
            body = if let detail = status.detail {
                "\(detail): \(level.title.lowercased())."
            } else {
                "\(level.title)."
            }
        case .cameBack:
            title = "\(agent.title) is back"
            body = "You can carry on."
        }
        // One identifier per agent: a second message about the same agent replaces the
        // first rather than stacking a history no one asked for.
        Task { await deliver(title: title, body: body, identifier: "status.\(agent.rawValue)") }
    }

    func post(_ alert: UsageWatch.Alert, now: Date = .now) {
        guard center != nil else { return }
        let message = Self.message(for: alert, now: now)
        // One identifier per window: 90% replaces 80% rather than sitting under it.
        Task { await deliver(title: message.title, body: message.body, identifier: "usage.\(alert.limit.id)") }
    }

    /// "Claude · Weekly · all models: 82% used", then the mark it passed and when the
    /// window starts over - the two things that decide what to do about it.
    static func message(for alert: UsageWatch.Alert, now: Date) -> (title: String, body: String) {
        let limit = alert.limit
        let title = "\(limit.agent.title) \u{00B7} \(limit.title): \(Format.percent(limit.percentUsed)) used"
        let passed = alert.threshold >= 100 ? "Used up." : "Past your \(alert.threshold)% mark."
        guard let end = limit.resetsAt, end > now else { return (title, passed) }
        return (title, "\(passed) Starts over in \(Format.short(end.timeIntervalSince(now))), \(Format.clock(end, now: now)).")
    }

    private func deliver(title: String, body: String, identifier: String) async {
        guard let center, await requestAuthorization() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        do {
            try await center.add(request)
            Log.app.notice("notified: \(title, privacy: .public)")
        } catch {
            Log.app.error("notification not posted: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Opens System Settings where the user can turn the app's notifications back on.
    func openSystemSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}
