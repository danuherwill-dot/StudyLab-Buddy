import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private static let timerEndID = "studylab.timer.end"

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: Preferences (toggled in Settings)

    static let taskRemindersKey = "taskRemindersEnabled"
    static let timerAlertsKey = "timerAlertsEnabled"

    private func isEnabled(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func cancelAllTaskReminders() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("studylab.task.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func sendTestNotification() async {
        guard await requestAuthorization() else { return }
        let content = UNMutableNotificationContent()
        content.title = "As notificações do StudyLab Buddy estão ativas"
        content.body = "Vais receber lembretes como este."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "studylab.test", content: content, trigger: trigger))
    }

    // MARK: Authorization

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: Task reminders

    private struct Reminder {
        let leadTime: TimeInterval
        let title: String
    }

    private func reminders(for type: TaskType) -> [Reminder] {
        let hour: TimeInterval = 3600, day: TimeInterval = 86_400
        switch type {
        case .homework:
            return [Reminder(leadTime: day, title: "TPC para amanhã"),
                    Reminder(leadTime: hour, title: "TPC para daqui a 1 hora"),
                    Reminder(leadTime: 0, title: "TPC para entregar agora")]
        case .assignment:
            return [Reminder(leadTime: 3 * day, title: "Trabalho para daqui a 3 dias"),
                    Reminder(leadTime: day, title: "Trabalho para amanhã"),
                    Reminder(leadTime: 0, title: "Trabalho para entregar agora")]
        case .test:
            return [Reminder(leadTime: 7 * day, title: "Teste daqui a 1 semana — começa a rever a matéria"),
                    Reminder(leadTime: 3 * day, title: "Teste daqui a 3 dias"),
                    Reminder(leadTime: day, title: "Teste amanhã"),
                    Reminder(leadTime: 2 * hour, title: "Teste daqui a 2 horas")]
        }
    }

    private func identifier(for task: StudyTask, index: Int) -> String {
        "studylab.task.\(task.id.uuidString).\(index)"
    }

    /// Replaces any pending reminders for the task. Does nothing when `remindMe` is off or the task is done.
    func scheduleReminders(for task: StudyTask) async {
        cancelReminders(for: task)
        guard task.remindMe, !task.isCompleted, isEnabled(Self.taskRemindersKey) else { return }
        guard await requestAuthorization() else { return }

        let subjectName = task.subject?.name
        for (index, reminder) in reminders(for: task.type).enumerated() {
            let fireDate = task.dueDate.addingTimeInterval(-reminder.leadTime)
            guard fireDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = [subjectName, task.title].compactMap { $0 }.joined(separator: " · ")
            content.sound = .default

            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let request = UNNotificationRequest(identifier: identifier(for: task, index: index),
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancelReminders(for task: StudyTask) {
        let ids = (0..<8).map { identifier(for: task, index: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: Timer

    func scheduleTimerEnd(after seconds: TimeInterval, title: String, body: String) {
        cancelTimerEnd()
        guard isEnabled(Self.timerAlertsKey) else { return }
        Task {
            guard await requestAuthorization() else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: Self.timerEndID, content: content, trigger: trigger))
        }
    }

    func cancelTimerEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.timerEndID])
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Show banners even while the app is in the foreground.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
