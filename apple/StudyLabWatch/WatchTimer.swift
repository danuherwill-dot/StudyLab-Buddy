import Foundation
import Observation
import UserNotifications
import WatchKit

/// Pomodoro / stopwatch / countdown for the watch. Time is derived from dates, so it stays correct
/// when the wrist is lowered; the end of a phase also schedules a notification.
@MainActor
@Observable
final class WatchTimer {
    enum Mode: String, CaseIterable, Identifiable {
        case pomodoro, stopwatch, countdown
        var id: String { rawValue }
        var title: String {
            switch self {
            case .pomodoro: "Pomodoro"
            case .stopwatch: "Cronómetro"
            case .countdown: "Contagem"
            }
        }
        var systemImage: String {
            switch self {
            case .pomodoro: "timer"
            case .stopwatch: "stopwatch"
            case .countdown: "hourglass"
            }
        }
    }

    enum Phase {
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

    enum RunState { case idle, running, paused }

    var mode: Mode = .pomodoro {
        didSet { if mode != oldValue { reset() } }
    }
    var subject: WatchSubject?
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var countdownMinutes = 30

    private(set) var state: RunState = .idle
    private(set) var phase: Phase = .focus
    private(set) var completedPomodoros = 0
    var lastLogMessage: String?

    var onLog: ((WatchSessionLog) -> Void)?

    @ObservationIgnored private var accumulated: TimeInterval = 0
    @ObservationIgnored private var segmentStart: Date?
    @ObservationIgnored private var completionTask: Task<Void, Never>?

    static let minimumLoggableSeconds: TimeInterval = 5

    // MARK: Derived values

    var phaseDuration: TimeInterval? {
        switch mode {
        case .stopwatch: nil
        case .countdown: TimeInterval(countdownMinutes * 60)
        case .pomodoro:
            switch phase {
            case .focus: TimeInterval(focusMinutes * 60)
            case .shortBreak: TimeInterval(shortBreakMinutes * 60)
            case .longBreak: TimeInterval(longBreakMinutes * 60)
            }
        }
    }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (segmentStart.map { now.timeIntervalSince($0) } ?? 0)
    }

    func displaySeconds(at now: Date) -> Int {
        if let duration = phaseDuration { return Int(max(0, duration - elapsed(at: now)).rounded(.up)) }
        return Int(elapsed(at: now))
    }

    func progress(at now: Date) -> Double {
        if let duration = phaseDuration, duration > 0 { return min(1, elapsed(at: now) / duration) }
        return elapsed(at: now).truncatingRemainder(dividingBy: 60) / 60
    }

    var statusLabel: String {
        switch mode {
        case .pomodoro: phase.title
        case .stopwatch: "Decorrido"
        case .countdown: "Restante"
        }
    }

    var isBreak: Bool { mode == .pomodoro && phase.isBreak }

    // MARK: Controls

    func start() {
        guard subject != nil, state != .running else { return }
        segmentStart = Date()
        state = .running
        scheduleCompletion()
    }

    func pause() {
        guard state == .running else { return }
        accumulated = elapsed(at: .now)
        segmentStart = nil
        state = .paused
        cancelCompletion()
    }

    /// Ends the session and sends the focused time to the iPhone.
    func finish() {
        guard state != .idle else { return }
        if !isBreak { log(seconds: elapsed(at: .now)) }
        reset()
    }

    func discard() { reset() }

    func skipBreak() {
        guard isBreak else { return }
        begin(.focus, autoStart: state == .running)
    }

    /// Call when the app becomes active again: a phase may have ended while the wrist was down.
    func reconcile() {
        guard state == .running, let duration = phaseDuration, elapsed(at: .now) >= duration else { return }
        phaseCompleted(duration: duration)
    }

    // MARK: Internals

    private func scheduleCompletion() {
        cancelCompletion()
        guard let duration = phaseDuration else { return }
        let remaining = max(0, duration - elapsed(at: .now))
        completionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            self?.phaseCompleted(duration: duration)
        }
        scheduleNotification(after: remaining)
    }

    private func cancelCompletion() {
        completionTask?.cancel()
        completionTask = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["studylab.watch.end"])
    }

    private func phaseCompleted(duration: TimeInterval) {
        WKInterfaceDevice.current().play(.success)
        switch mode {
        case .countdown:
            log(seconds: duration)
            reset()
        case .pomodoro:
            if phase == .focus {
                log(seconds: duration)
                completedPomodoros += 1
                begin(completedPomodoros % 4 == 0 ? .longBreak : .shortBreak, autoStart: true)
            } else {
                begin(.focus, autoStart: false)
            }
        case .stopwatch:
            break
        }
    }

    private func begin(_ newPhase: Phase, autoStart: Bool) {
        cancelCompletion()
        phase = newPhase
        accumulated = 0
        if autoStart {
            segmentStart = Date()
            state = .running
            scheduleCompletion()
        } else {
            segmentStart = nil
            state = .paused
        }
    }

    private func log(seconds: TimeInterval) {
        guard seconds >= Self.minimumLoggableSeconds, let subject else { return }
        let total = Int(seconds.rounded())
        onLog?(WatchSessionLog(subjectID: subject.id, seconds: total, date: .now, notes: ""))
        lastLogMessage = "\(DurationFormat.short(seconds: total)) registados em \(subject.name)"
    }

    private func reset() {
        cancelCompletion()
        segmentStart = nil
        accumulated = 0
        phase = .focus
        completedPomodoros = 0
        state = .idle
    }

    private func scheduleNotification(after seconds: TimeInterval) {
        let name = subject?.name ?? "estudo"
        let content = UNMutableNotificationContent()
        switch mode {
        case .pomodoro where phase == .focus:
            content.title = "Bloco de foco concluído 🎉"
            content.body = "Bom trabalho em \(name). Hora de uma pausa."
        case .pomodoro:
            content.title = "A pausa terminou"
            content.body = "Pronto para outro bloco de foco em \(name)?"
        case .countdown:
            content.title = "Tempo esgotado ⏰"
            content.body = "A contagem de \(name) terminou."
        case .stopwatch:
            return
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "studylab.watch.end", content: content, trigger: trigger))
    }
}
