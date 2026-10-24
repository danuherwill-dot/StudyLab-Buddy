#if os(iOS)
import ActivityKit
import Foundation

/// Shared by the app (which starts/updates the Live Activity) and the widget extension (which draws it).
struct StudyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "Foco", "Pausa curta", "Cronómetro", "Contagem"…
        var title: String
        var isPaused: Bool
        var isBreak: Bool
        /// Seconds to show while paused (remaining for countdown/pomodoro, elapsed for stopwatch).
        var pausedSeconds: Int
        /// Running countdown/pomodoro: the phase window. The system draws the ticking time itself.
        var startDate: Date?
        var endDate: Date?
        /// 0...1 progress while paused (the running ring is drawn by the system from the dates).
        var pausedProgress: Double = 0
        /// Pomodoros finished in the current set of four; nil outside Pomodoro mode.
        var pomodorosDone: Int?
        /// Running stopwatch: the moment it started counting from zero.
        var countUpFrom: Date?
    }

    var subjectName: String
    var colorHex: String
}

#endif
