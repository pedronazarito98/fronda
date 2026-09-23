import AppKit
import UserNotifications

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["runID"] as? String, UUID(uuidString: id) != nil
        else { return }
        await MainActor.run { if let url = URL(string: "harness://run/" + id) { NSWorkspace.shared.open(url) } }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions
    { [.banner, .sound] }
}
