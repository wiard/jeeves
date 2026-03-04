import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let emergenceCategory = "emergence-card"

    private init() {}

    func requestPermission() {
        let investigate = UNNotificationAction(
            identifier: "investigate",
            title: "Investigate",
            options: [.foreground]
        )
        let ignore = UNNotificationAction(
            identifier: "ignore",
            title: "Ignore",
            options: []
        )
        let bookmark = UNNotificationAction(
            identifier: "bookmark",
            title: "Bookmark",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: emergenceCategory,
            actions: [investigate, ignore, bookmark],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func notifyNewProposals(_ proposals: [Proposal]) {
        guard !proposals.isEmpty else { return }

        if proposals.count > 10 {
            let content = UNMutableNotificationContent()
            content.title = TextKeys.appTitle
            content.body = String(format: TextKeys.Notifications.multipleProposals, proposals.count)
            content.sound = .default
            scheduleNotification(id: "batch-\(UUID().uuidString.prefix(8))", content: content)
            return
        }

        for proposal in proposals {
            let content = UNMutableNotificationContent()
            content.title = TextKeys.appTitle
            content.body = String(format: TextKeys.Notifications.newProposal, proposal.agentId, proposal.title)
            content.sound = .default
            scheduleNotification(id: "proposal-\(proposal.proposalId)", content: content)
        }
    }

    func notifyEmergence(_ cluster: EmergenceCluster) {
        let content = UNMutableNotificationContent()
        content.title = "Unexpected connection detected"
        content.body = cluster.summary
        content.categoryIdentifier = emergenceCategory
        content.sound = .default
        scheduleNotification(id: "emergence-\(cluster.clusterId)", content: content)
    }

    func updateBadge(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
    }

    private func scheduleNotification(id: String, content: UNMutableNotificationContent) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
