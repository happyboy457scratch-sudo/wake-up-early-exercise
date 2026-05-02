import Foundation
import UserNotifications

struct AlarmScheduler {
    static func scheduleAlarm(hour: Int, minute: Int) async throws {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        content.body = "Wake up!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-alarm", content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: ["daily-alarm"])
        try await center.add(request)
    }

    static func cancelAlarm() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-alarm"])
    }
}
