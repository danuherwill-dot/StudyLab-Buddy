#if os(iOS)
import Foundation
import SwiftData
import WatchConnectivity

/// Keeps the Apple Watch app in sync: pushes subjects, today's classes and tasks to the watch,
/// and stores study sessions / task ticks that come back from it.
@MainActor
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    private var context: ModelContext?
    private var saveObserver: NSObjectProtocol?
    private var pending: Task<Void, Never>?

    func start(context: ModelContext) {
        self.context = context
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        if saveObserver == nil {
            saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.schedulePush() }
            }
        }
    }

    // MARK: IDs

    private func encode(_ id: PersistentIdentifier) -> String {
        (try? JSONEncoder().encode(id))?.base64EncodedString() ?? ""
    }

    private func decode(_ string: String) -> PersistentIdentifier? {
        guard let data = Data(base64Encoded: string) else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }

    // MARK: Phone → Watch

    private func schedulePush() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            pushSnapshot()
        }
    }

    func pushSnapshot() {
        guard let context, WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }

        let subjects = (try? context.fetch(FetchDescriptor<Subject>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let entries = (try? context.fetch(FetchDescriptor<TimetableEntry>(sortBy: [SortDescriptor(\.startTime)]))) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<StudyTask>(sortBy: [SortDescriptor(\.dueDate)]))) ?? []

        let recent = Date.now.addingTimeInterval(-3 * 86_400)
        let watchTasks = tasks
            .filter { !$0.isCompleted || $0.dueDate > recent }
            .prefix(40)
            .map { task in
                WatchTask(id: encode(task.persistentModelID), title: task.title,
                          subjectName: task.subject?.name ?? "", colorHex: task.subject?.colorHex ?? "#4F6DF2",
                          typeTitle: task.type.title, typeIcon: task.type.systemImage,
                          due: task.dueDate, isCompleted: task.isCompleted)
            }

        let snapshot = WatchSnapshot(
            subjects: subjects.map { WatchSubject(id: encode($0.persistentModelID), name: $0.name, colorHex: $0.colorHex) },
            classes: entries.map { entry in
                WatchClass(id: encode(entry.persistentModelID), subjectName: entry.subject?.name ?? "—",
                           colorHex: entry.subject?.colorHex ?? "#64748B", weekday: entry.dayOfWeek.rawValue,
                           start: entry.startTime, end: entry.endTime, room: entry.room)
            },
            tasks: Array(watchTasks),
            generated: .now)

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? session.updateApplicationContext([WatchKey.snapshot: data])
    }

    // MARK: Watch → Phone

    private func handle(_ info: [String: Any]) {
        guard let context else { return }

        if let data = info[WatchKey.session] as? Data, let log = try? JSONDecoder().decode(WatchSessionLog.self, from: data),
           let id = decode(log.subjectID), let subject = context.model(for: id) as? Subject {
            context.insert(StudySession(subject: subject, durationInSeconds: log.seconds,
                                        dateCompleted: log.date, notes: log.notes))
            try? context.save()
        }

        if let taskID = info[WatchKey.toggleTask] as? String, let id = decode(taskID),
           let task = context.model(for: id) as? StudyTask {
            task.isCompleted.toggle()
            try? context.save()
            Task { await NotificationManager.shared.scheduleReminders(for: task) }
        }

        if info[WatchKey.requestSnapshot] != nil { pushSnapshot() }
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.pushSnapshot() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.pushSnapshot() }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.handle(userInfo) }
    }
}
#endif
