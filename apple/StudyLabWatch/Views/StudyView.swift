import SwiftUI

struct StudyView: View {
    @Environment(WatchTimer.self) private var timer
    @Environment(ConnectivityManager.self) private var link
    @State private var showSubjects = false

    private var accent: Color {
        if timer.isBreak { return .green }
        return timer.subject.map { Color(hex: $0.colorHex) } ?? .accentColor
    }

    var body: some View {
        NavigationStack {
            Group {
                if timer.state == .idle { setup } else { running }
            }
            .containerBackground(accent.gradient, for: .navigation)
            .sheet(isPresented: $showSubjects) { SubjectPicker() }
        }
    }

    // MARK: Setup

    private var setup: some View {
        @Bindable var timer = timer
        return ScrollView {
            VStack(spacing: 10) {
                Button {
                    showSubjects = true
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(timer.subject.map { Color(hex: $0.colorHex) } ?? .gray).frame(width: 10, height: 10)
                        Text(timer.subject?.name ?? "Disciplina")
                            .lineLimit(1)
                            .font(.footnote.weight(.semibold))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                }
                .glassButtonStyle()

                HStack(spacing: 6) {
                    ForEach(WatchTimer.Mode.allCases) { mode in
                        Button {
                            timer.mode = mode
                        } label: {
                            Image(systemName: mode.systemImage)
                                .frame(maxWidth: .infinity)
                        }
                        .glassButtonStyle()
                        .tint(timer.mode == mode ? .white : nil)
                        .accessibilityLabel(mode.title)
                    }
                }

                switch timer.mode {
                case .pomodoro:
                    Stepper(value: $timer.focusMinutes, in: 1...120) {
                        Text("Foco \(timer.focusMinutes) min").font(.footnote)
                    }
                case .countdown:
                    Stepper(value: $timer.countdownMinutes, in: 1...240) {
                        Text("\(timer.countdownMinutes) min").font(.footnote)
                    }
                case .stopwatch:
                    EmptyView()
                }

                Button {
                    if timer.subject == nil { showSubjects = true } else { timer.start() }
                } label: {
                    Label("Iniciar", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .glassProminentButtonStyle()
                .tint(.white.opacity(0.9))
                .foregroundStyle(accent)

                if let message = timer.lastLogMessage {
                    Text(message)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .navigationTitle("Estudar")
    }

    // MARK: Running

    private var running: some View {
        VStack(spacing: 6) {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let now = context.date
                ZStack {
                    Circle().stroke(.white.opacity(0.2), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: timer.progress(at: now))
                        .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(timer.subject?.name ?? "")
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                        Text(timer.statusLabel.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(DurationFormat.clock(seconds: timer.displaySeconds(at: now)))
                            .font(.system(size: 34, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        if timer.mode == .pomodoro {
                            HStack(spacing: 4) {
                                ForEach(0..<4, id: \.self) { index in
                                    Circle()
                                        .fill(index < timer.completedPomodoros % 4 ? .white : .white.opacity(0.3))
                                        .frame(width: 5, height: 5)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 128, height: 128)

            HStack(spacing: 10) {
                Button {
                    timer.state == .running ? timer.pause() : timer.start()
                } label: {
                    Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                }
                .glassButtonStyle()

                Button {
                    timer.finish()
                } label: {
                    Image(systemName: "checkmark")
                }
                .glassProminentButtonStyle()
                .tint(.white.opacity(0.9))
                .foregroundStyle(accent)

                if timer.isBreak {
                    Button { timer.skipBreak() } label: { Image(systemName: "forward.fill") }
                        .glassButtonStyle()
                }
            }
        }
    }
}

struct SubjectPicker: View {
    @Environment(WatchTimer.self) private var timer
    @Environment(ConnectivityManager.self) private var link
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let subjects = link.snapshot?.subjects, !subjects.isEmpty {
                    ForEach(subjects) { subject in
                        Button {
                            timer.subject = subject
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Circle().fill(Color(hex: subject.colorHex)).frame(width: 12, height: 12)
                                Text(subject.name)
                                Spacer()
                                if timer.subject?.id == subject.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } else {
                    Text("Abre o StudyLab no iPhone para sincronizar as tuas disciplinas.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Disciplina")
        }
    }
}
