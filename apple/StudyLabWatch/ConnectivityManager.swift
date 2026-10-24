import Foundation
import Observation
import WatchConnectivity

/// Talks to the iPhone app: receives subjects / classes / tasks, sends finished sessions and task ticks.
@MainActor
@Observable
final class ConnectivityManager: NSObject, WCSessionDelegate {
    private(set) var snapshot: WatchSnapshot?

    private static let cacheKey = "studylab.snapshot"

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey) {
            snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data)
        }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func apply(_ context: [String: Any]) {
        guard let data = context[WatchKey.snapshot] as? Data,
              let decoded = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        snapshot = decoded
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }

    // MARK: Watch → iPhone

    func send(_ log: WatchSessionLog) {
        guard let data = try? JSONEncoder().encode(log) else { return }
        WCSession.default.transferUserInfo([WatchKey.session: data])
    }

    func toggle(_ task: WatchTask) {
        if let index = snapshot?.tasks.firstIndex(where: { $0.id == task.id }) {
            snapshot?.tasks[index].isCompleted.toggle()
            if let snapshot, let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: Self.cacheKey)
            }
        }
        WCSession.default.transferUserInfo([WatchKey.toggleTask: task.id])
    }

    func requestSnapshot() {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo([WatchKey.requestSnapshot: true])
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in
            self.apply(context)
            self.requestSnapshot()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }
}
