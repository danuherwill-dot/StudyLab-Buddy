import ActivityKit
import SwiftUI
import WidgetKit

struct StudyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityAttributes.self) { context in
            LockScreenActivityView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.4))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let tint = accent(context.attributes, context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivityRing(state: context.state, tint: tint, icon: iconName(context.state), lineWidth: 5)
                        .frame(width: 52, height: 52)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 0) {
                        Text(context.attributes.subjectName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                        ActivityTimerText(state: context.state)
                            .font(.system(size: 40, weight: .thin, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 6) {
                        PhasePill(text: context.state.isPaused ? "EM PAUSA" : context.state.title.uppercased(), tint: tint)
                        PomodoroDots(done: context.state.pomodorosDone, tint: tint)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActivityBar(state: context.state, tint: tint)
                        .padding(.horizontal, 6)
                        .padding(.top, 4)
                }
            } compactLeading: {
                ActivityRing(state: context.state, tint: tint, icon: iconName(context.state), lineWidth: 2.5)
                    .frame(width: 22, height: 22)
            } compactTrailing: {
                ActivityTimerText(state: context.state)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .frame(width: 50)
            } minimal: {
                ActivityRing(state: context.state, tint: tint, icon: iconName(context.state), lineWidth: 2.5)
                    .frame(width: 22, height: 22)
            }
            .keylineTint(tint)
        }
    }
}

private func accent(_ attributes: StudyActivityAttributes, _ state: StudyActivityAttributes.ContentState) -> Color {
    state.isBreak ? .green : Color(hex: attributes.colorHex)
}

private func iconName(_ state: StudyActivityAttributes.ContentState) -> String {
    if state.isPaused { return "pause.fill" }
    return state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile"
}

// MARK: Lock screen

private struct LockScreenActivityView: View {
    let attributes: StudyActivityAttributes
    let state: StudyActivityAttributes.ContentState

    private var tint: Color { accent(attributes, state) }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ActivityRing(state: state, tint: tint, icon: iconName(state), lineWidth: 6)
                    .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 7) {
                    Text(attributes.subjectName)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        PhasePill(text: state.isPaused ? "EM PAUSA" : state.title.uppercased(), tint: tint)
                        PomodoroDots(done: state.pomodorosDone, tint: tint)
                    }
                }
                Spacer(minLength: 4)
                ActivityTimerText(state: state)
                    .font(.system(size: 46, weight: .thin, design: .rounded))
                    .frame(maxWidth: 150, alignment: .trailing)
            }
            ActivityBar(state: state, tint: tint)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            ZStack {
                LinearGradient(colors: [tint.opacity(0.55), Color(red: 0.05, green: 0.06, blue: 0.16).opacity(0.9)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(tint.opacity(0.5)).frame(width: 180).blur(radius: 50).offset(x: 120, y: -50)
                Circle().fill(Color.purple.opacity(0.35)).frame(width: 150).blur(radius: 50).offset(x: -140, y: 60)
            }
        }
    }
}

// MARK: Pieces

/// Circular progress that the system animates by itself while running.
private struct ActivityRing: View {
    let state: StudyActivityAttributes.ContentState
    let tint: Color
    let icon: String
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.22), lineWidth: lineWidth)

            if !state.isPaused, let start = state.startDate, let end = state.endDate, end > start {
                ArcFromDates(start: start, end: end, tint: tint, lineWidth: lineWidth)
            } else {
                Circle()
                    .trim(from: 0, to: state.isPaused || state.endDate != nil ? max(0.02, state.pausedProgress) : 1)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            Image(systemName: icon)
                .font(.system(size: lineWidth > 4 ? 22 : 9, weight: .semibold))
                .foregroundStyle(tint)
        }
    }
}

/// An arc that fills between two dates (updated by the system via a timer-driven gauge).
private struct ArcFromDates: View {
    let start: Date
    let end: Date
    let tint: Color
    let lineWidth: CGFloat

    var body: some View {
        // `Gauge(timerInterval:)` is not available, so use a circular timer ProgressView styled as a ring.
        ProgressView(timerInterval: start...end, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(RingProgressStyle(tint: tint, lineWidth: lineWidth))
    }
}

private struct RingProgressStyle: ProgressViewStyle {
    let tint: Color
    let lineWidth: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        Circle()
            .trim(from: 0, to: max(0.02, configuration.fractionCompleted ?? 0))
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

private struct PhasePill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.2)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(tint.opacity(0.28), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.6), lineWidth: 0.8))
            .foregroundStyle(.white)
    }
}

private struct PomodoroDots: View {
    let done: Int?
    let tint: Color

    var body: some View {
        if let done {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < done ? tint : Color.white.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
}

private struct ActivityBar: View {
    let state: StudyActivityAttributes.ContentState
    let tint: Color

    var body: some View {
        if !state.isPaused, let start = state.startDate, let end = state.endDate, end > start {
            ProgressView(timerInterval: start...end, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(tint)
        } else {
            ProgressView(value: state.isPaused || state.endDate != nil ? state.pausedProgress : 1)
                .tint(tint.opacity(state.isPaused ? 0.5 : 1))
        }
    }
}

/// The ticking time. While running, the system animates it by itself, so no updates are needed each second.
private struct ActivityTimerText: View {
    let state: StudyActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isPaused {
                Text(Self.format(state.pausedSeconds))
            } else if let end = state.endDate {
                let now = Date.now
                Text(timerInterval: now...max(end, now), countsDown: true)
            } else if let from = state.countUpFrom {
                Text(from, style: .timer)
            } else {
                Text(Self.format(state.pausedSeconds))
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    static func format(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
