import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() {
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
        content.title = TextKeys.appTitle
        content.body = TextKeys.Notifications.emergenceDetected
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
