import SwiftUI
import SwiftData
import Observation
#if os(iOS)
import UIKit
#endif

enum TimerMode: String, CaseIterable, Identifiable {
    case clock, pomodoro, stopwatch, countdown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: "Relógio"
        case .pomodoro: "Pomodoro"
        case .stopwatch: "Cronómetro"
        case .countdown: "Contagem"
        }
    }

    var systemImage: String {
        switch self {
        case .clock: "clock"
        case .pomodoro: "timer"
        case .stopwatch: "stopwatch"
        case .countdown: "hourglass"
        }
    }
}

enum PomodoroPhase {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus: "Foco"
        case .shortBreak: "Pausa curta"
        case .longBreak: "Pausa longa"
        }
    }

    var isBreak: Bool { self != .focus }
}

enum TimerState { case idle, running, paused }

struct ChecklistItem: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var isDone = false
}

/// Drives the Study Hub. Time is derived from wall-clock dates, so it stays correct
/// when the app is backgrounded; the tick loop only refreshes the UI.
@MainActor
@Observable
final class TimerManager {
    // MARK: Settings (adjustable while idle)
    var mode: TimerMode = .pomodoro {
        didSet { if mode != oldValue { resetTimer() } }
    }
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var countdownMinutes = 30

    // MARK: Session context
    var subject: Subject?
    var checklist: [ChecklistItem] = []

    // MARK: Observable state
    private(set) var state: TimerState = .idle {
        didSet {
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = (state == .running)
            #endif
        }
    }
    private(set) var phase: PomodoroPhase = .focus
    private(set) var completedPomodoros = 0
    /// Seconds elapsed in the current phase.
    private(set) var elapsed: TimeInterval = 0

    var showSubjectRequired = false
    var lastLogMessage: String?

    // MARK: Internals
    @ObservationIgnored private var accumulated: TimeInterval = 0
    @ObservationIgnored private var segmentStart: Date?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var context: ModelContext?

    static let minimumLoggableSeconds: TimeInterval = 5

    func configure(context: ModelContext) {
        self.context = context
    }

    // MARK: Derived values

    var isActive: Bool { mode != .clock && state != .idle }

    var phaseDuration: TimeInterval? {
        switch mode {
        case .clock, .stopwatch:
            return nil
        case .countdown:
            return TimeInterval(countdownMinutes * 60)
        case .pomodoro:
            switch phase {
            case .focus: return TimeInterval(focusMinutes * 60)
            case .shortBreak: return TimeInterval(shortBreakMinutes * 60)
            case .longBreak: return TimeInterval(longBreakMinutes * 60)
            }
        }
    }

    /// Whole seconds to show on screen (remaining for countdown/pomodoro, elapsed for stopwatch).
    var displaySeconds: Int {
        if let duration = phaseDuration {
            return Int(max(0, duration - elapsed).rounded(.up))
        }
        return Int(elapsed)
    }

    /// 0...1 for the progress ring.
    var ringProgress: Double {
        if let duration = phaseDuration, duration > 0 {
            return min(1, elapsed / duration)
        }
        return elapsed.truncatingRemainder(dividingBy: 60) / 60
    }

    var statusLabel: String {
        switch mode {
        case .clock: return ""
        case .pomodoro: return phase.title
        case .stopwatch: return "Decorrido"
        case .countdown: return "Restante"
        }
    }

    // MARK: Controls

    func start() {
        guard mode != .clock, state != .running else { return }
        guard subject != nil else {
            showSubjectRequired = true
            return
        }
        segmentStart = Date()
        state = .running
        scheduleEndNotification()
        startTicking()
        syncLiveActivity()
    }

    func pause() {
        guard state == .running else { return }
        accumulated = currentElapsed()
        elapsed = accumulated
        segmentStart = nil
        state = .paused
        stopTicking()
        NotificationManager.shared.cancelTimerEnd()
        syncLiveActivity()
    }

    /// Stops the session, saves the focused time to SwiftData and clears the checklist.
    func finish() {
        guard state != .idle else { return }
        elapsed = currentElapsed()
        if !(mode == .pomodoro && phase.isBreak) {
            logSession(seconds: elapsed)
        }
        endSession()
    }

    /// Stops the session without saving anything.
    func discard() {
        endSession()
    }

    func skipBreak() {
        guard mode == .pomodoro, phase.isBreak else { return }
        beginPhase(.focus, autoStart: state == .running)
    }

    // MARK: Checklist

    func addChecklistItem(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        checklist.append(ChecklistItem(title: trimmed))
    }

    func removeChecklistItem(id: UUID) {
        checklist.removeAll { $0.id == id }
    }

    // MARK: Ticking

    private func startTicking() {
        stopTicking()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func currentElapsed() -> TimeInterval {
        accumulated + (segmentStart.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private func tick() {
        guard state == .running else { return }
        elapsed = currentElapsed()
        if let duration = phaseDuration, elapsed >= duration {
            phaseCompleted(duration: duration)
        }
    }

    private func phaseCompleted(duration: TimeInterval) {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        switch mode {
        case .countdown:
            logSession(seconds: duration)
            endSession()
        case .pomodoro:
            if phase == .focus {
                logSession(seconds: duration)
                completedPomodoros += 1
                beginPhase(completedPomodoros % 4 == 0 ? .longBreak : .shortBreak, autoStart: true)
            } else {
                // After a break, wait for the student to start the next focus block.
                beginPhase(.focus, autoStart: false)
            }
        case .clock, .stopwatch:
            break
        }
    }

    private func beginPhase(_ newPhase: PomodoroPhase, autoStart: Bool) {
        phase = newPhase
        accumulated = 0
        elapsed = 0
        NotificationManager.shared.cancelTimerEnd()
        if autoStart {
            segmentStart = Date()
            state = .running
            scheduleEndNotification()
            startTicking()
        } else {
            segmentStart = nil
            state = .paused
            stopTicking()
        }
        syncLiveActivity()
    }

    // MARK: Live Activity

    private func syncLiveActivity() {
        #if os(iOS)
        guard mode != .clock, state != .idle, let subject else {
            LiveActivityManager.shared.end()
            return
        }
        let now = Date()
        var content = StudyActivityAttributes.ContentState(
            title: statusLabel,
            isPaused: state == .paused,
            isBreak: mode == .pomodoro && phase.isBreak,
            pausedSeconds: displaySeconds,
            pausedProgress: ringProgress,
            pomodorosDone: mode == .pomodoro ? completedPomodoros % 4 : nil)
        if state == .running {
            if let duration = phaseDuration {
                content.startDate = now.addingTimeInterval(-elapsed)
                content.endDate = now.addingTimeInterval(duration - elapsed)
            } else {
                content.countUpFrom = now.addingTimeInterval(-elapsed)
            }
        }
        LiveActivityManager.shared.startOrUpdate(
            attributes: StudyActivityAttributes(subjectName: subject.name, colorHex: subject.colorHex),
            state: content)
        #endif
    }

    private func scheduleEndNotification() {
        guard let duration = phaseDuration else { return }
        let remaining = duration - elapsed
        let name = subject?.name ?? "estudo"
        switch mode {
        case .pomodoro where phase == .focus:
            NotificationManager.shared.scheduleTimerEnd(after: remaining, title: "Bloco de foco concluído 🎉",
                                                        body: "Bom trabalho em \(name). Hora de uma pausa.")
        case .pomodoro:
            NotificationManager.shared.scheduleTimerEnd(after: remaining, title: "A pausa terminou",
                                                        body: "Pronto para outro bloco de foco em \(name)?")
        case .countdown:
            NotificationManager.shared.scheduleTimerEnd(after: remaining, title: "Tempo esgotado ⏰",
                                                        body: "A contagem de \(name) terminou.")
        default:
            break
        }
    }

    // MARK: Persistence

    private func logSession(seconds: TimeInterval) {
        guard seconds >= Self.minimumLoggableSeconds, let subject, let context else { return }
        let total = Int(seconds.rounded())
        let session = StudySession(subject: subject, durationInSeconds: total, notes: checklistNotes())
        context.insert(session)
        try? context.save()
        lastLogMessage = "\(DurationFormat.short(seconds: total)) registados em \(subject.name)"
    }

    private func checklistNotes() -> String {
        checklist
            .map { ($0.isDone ? "✓ " : "○ ") + $0.title }
            .joined(separator: "\n")
    }

    // MARK: Reset

    private func endSession() {
        resetTimer()
        checklist.removeAll()
    }

    private func resetTimer() {
        #if os(iOS)
        LiveActivityManager.shared.end()
        #endif
        stopTicking()
        NotificationManager.shared.cancelTimerEnd()
        segmentStart = nil
        accumulated = 0
        elapsed = 0
        phase = .focus
        completedPomodoros = 0
        state = .idle
    }
}
