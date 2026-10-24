#if os(iOS)
import ActivityKit
import Foundation

/// Starts, updates and ends the lock-screen / Dynamic Island Live Activity for a study session.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<StudyActivityAttributes>?

    func startOrUpdate(attributes: StudyActivityAttributes, state: StudyActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        if let activity {
            Task { await activity.update(content) }
        } else {
            activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
    }

    func end() {
        guard let current = activity else { return }
        activity = nil
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }
}

#endif
