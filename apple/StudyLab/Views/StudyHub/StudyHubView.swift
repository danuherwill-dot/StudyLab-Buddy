import SwiftUI
import SwiftData

struct StudyHubView: View {
    @Environment(TimerManager.self) private var timer
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State private var showSubjects = false
    @State private var showSettings = false
    @State private var showDiscardConfirm = false
    @State private var newItem = ""

    #if os(macOS)
    private let ringSize: CGFloat = 340
    #else
    private let ringSize: CGFloat = 300
    #endif

    var body: some View {
        @Bindable var timer = timer

        NavigationStack {
            ZStack {
                background

                scroller
                    .dismissKeyboardOnScroll()
            }
            .navigationTitle("Estudar")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .leadingBar) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .disabled(timer.isActive)
                }
                ToolbarItem(placement: .trailingBar) {
                    Button { showSubjects = true } label: { Image(systemName: "books.vertical") }
                        .disabled(timer.isActive)
                }
            }
            #if os(iOS)
            .toolbar(timer.isActive ? .hidden : .visible, for: .tabBar)
            .toolbar(timer.state == .running ? .hidden : .visible, for: .navigationBar)
            #endif
            .animation(.easeInOut(duration: 0.25), value: timer.state)
            .overlay(alignment: .top) { logToast }
            .sheet(isPresented: $showSubjects) { SubjectsView().formSheet() }
            .sheet(isPresented: $showSettings) { SettingsView().formSheet() }
            .alert("Escolhe primeiro uma disciplina", isPresented: $timer.showSubjectRequired) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Cada sessão de estudo fica associada a uma disciplina, para aparecer corretamente nas estatísticas.")
            }
            .confirmationDialog("Descartar esta sessão?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Descartar sem guardar", role: .destructive) { timer.discard() }
                Button("Continuar", role: .cancel) {}
            }
        }
    }

    // MARK: Layout

    /// On Mac the content is centred vertically in the window.
    @ViewBuilder
    private var scroller: some View {
        #if os(macOS)
        GeometryReader { geo in
            ScrollView {
                layout
                    .padding(24)
                    .frame(minHeight: geo.size.height)
            }
        }
        #else
        ScrollView {
            layout
                .padding()
        }
        #endif
    }

    /// Single column on iPhone; timer on the left and settings on the right on Mac.
    @ViewBuilder
    private var layout: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: 40) {
            VStack(spacing: 30) {
                timerDisplay
                if timer.mode != .clock { controls.frame(maxWidth: 420) }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)

            VStack(spacing: 18) {
                modePicker
                subjectSelector
                if timer.state == .idle { durationControls }
                if timer.mode != .clock { checklistCard }
            }
            .frame(width: 400)
        }
        .frame(maxWidth: 1100)
        .frame(maxWidth: .infinity)
        #else
        VStack(spacing: 22) {
            modePicker
            subjectSelector
            timerDisplay
            if timer.mode != .clock { controls }
            if timer.state == .idle { durationControls }
            if timer.mode != .clock { checklistCard }
        }
        #endif
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            Color.appBackground
            if colorScheme == .dark {
                LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.14), .black],
                               startPoint: .top, endPoint: .bottom)
            }
            Circle().fill(accent.opacity(colorScheme == .dark ? 0.40 : 0.28))
                .frame(width: 320).blur(radius: 100).offset(x: 110, y: -260)
            Circle().fill(Color.purple.opacity(colorScheme == .dark ? 0.32 : 0.18))
                .frame(width: 300).blur(radius: 100).offset(x: -120, y: 300)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: accent)
    }

    private var accent: Color {
        if timer.mode == .pomodoro && timer.phase.isBreak { return .green }
        return timer.subject?.color ?? .accentColor
    }

    // MARK: Mode picker

    private var modePicker: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(TimerMode.allCases) { mode in
                    let selected = timer.mode == mode
                    Button {
                        withAnimation(.snappy) { timer.mode = mode }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mode.systemImage).font(.title3)
                            Text(mode.title).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selected ? .white : .primary)
                        .glassEffect(selected ? .regular.tint(accent.opacity(0.7)).interactive() : .regular.interactive(),
                                     in: .rect(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .disabled(timer.state != .idle)
                }
            }
        }
        .opacity(timer.state == .running ? 0 : 1)
    }

    // MARK: Subject

    private var subjectSelector: some View {
        let missing = timer.subject == nil
        return Menu {
            ForEach(subjects) { subject in
                Button {
                    timer.subject = subject
                } label: {
                    if timer.subject?.persistentModelID == subject.persistentModelID {
                        Label(subject.name, systemImage: "checkmark")
                    } else {
                        Text(subject.name)
                    }
                }
            }
            Divider()
            Button("Gerir disciplinas…", systemImage: "plus") { showSubjects = true }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(timer.subject?.color ?? .gray)
                    .frame(width: 12, height: 12)
                Text(timer.subject?.name ?? (subjects.isEmpty ? "Adiciona uma disciplina para começar" : "Escolhe uma disciplina"))
                    .fontWeight(.medium)
                Image(systemName: "chevron.up.chevron.down").font(.caption)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassEffect(missing ? .regular.tint(.orange.opacity(0.4)).interactive() : .regular.interactive(),
                         in: .capsule)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .disabled(timer.isActive)
        .foregroundStyle(.primary)
    }

    // MARK: Display

    @ViewBuilder
    private var timerDisplay: some View {
        if timer.mode == .clock {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = Calendar.current.component(.second, from: context.date)
                ZStack {
                    disc
                    TickRing(progress: Double(seconds + 1) / 60, tint: accent, size: ringSize)
                    VStack(spacing: 8) {
                        Text(context.date, format: .dateTime.hour().minute())
                            .font(.system(size: 74, weight: .thin, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .foregroundStyle(timeGradient)
                        Text(context.date, format: .dateTime.weekday(.wide))
                            .font(.headline)
                        Text(context.date, format: .dateTime.day().month(.wide))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(40)
                }
                .frame(width: ringSize, height: ringSize)
            }
        } else {
            ZStack {
                disc
                TickRing(progress: timer.ringProgress, tint: accent, size: ringSize)
                VStack(spacing: 8) {
                    Text(timer.statusLabel.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .glassEffect(.regular.tint(accent.opacity(0.35)), in: .capsule)
                    Text(DurationFormat.clock(seconds: timer.displaySeconds))
                        .font(.system(size: 64, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(timeGradient)
                        .contentTransition(.numericText())
                    if timer.mode == .pomodoro {
                        pomodoroDots
                    }
                }
                .padding(40)
            }
            .frame(width: ringSize, height: ringSize)
        }
    }

    private var disc: some View {
        Circle()
            .fill(.clear)
            .frame(width: ringSize - 56, height: ringSize - 56)
            .glassEffect(.regular, in: .circle)
    }

    private var timeGradient: LinearGradient {
        LinearGradient(colors: [.primary, .primary.opacity(0.65)], startPoint: .top, endPoint: .bottom)
    }

    private var pomodoroDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < timer.completedPomodoros % 4 ? accent : .primary.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: Duration settings

    @ViewBuilder
    private var durationControls: some View {
        @Bindable var timer = timer
        switch timer.mode {
        case .pomodoro:
            VStack(spacing: 6) {
                StepperRow("Foco", value: $timer.focusMinutes, range: 1...120)
                Divider()
                StepperRow("Pausa curta", value: $timer.shortBreakMinutes, range: 1...30)
                Divider()
                StepperRow("Pausa longa", value: $timer.longBreakMinutes, range: 1...60)
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
        case .countdown:
            StepperRow("Duração", value: $timer.countdownMinutes, range: 1...240)
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
        case .clock, .stopwatch:
            EmptyView()
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 14) {
            if timer.state == .idle {
                Button { timer.start() } label: {
                    Label("Iniciar", systemImage: "play.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(accent)
            } else {
                GlassEffectContainer(spacing: 24) {
                    HStack(spacing: 28) {
                        circleButton("xmark", label: "Descartar", tint: .red, size: 58) { showDiscardConfirm = true }
                        circleButton(timer.state == .running ? "pause.fill" : "play.fill",
                                     label: timer.state == .running ? "Pausar" : "Retomar",
                                     tint: accent, size: 86) {
                            if timer.state == .running { timer.pause() } else { timer.start() }
                        }
                        circleButton("checkmark", label: "Terminar", tint: .green, size: 58) { timer.finish() }
                    }
                }
            }

            if timer.mode == .pomodoro && timer.phase.isBreak {
                Button("Saltar pausa") { timer.skipBreak() }
                    .font(.subheadline)
            }
        }
    }

    private func circleButton(_ systemImage: String, label: String, tint: Color, size: CGFloat,
                              action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .frame(width: size, height: size)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(tint)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Checklist

    private var checklistCard: some View {
        @Bindable var timer = timer
        let done = timer.checklist.filter(\.isDone).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Lista de foco", systemImage: "checklist").font(.headline)
                Spacer()
                if !timer.checklist.isEmpty {
                    Text("\(done)/\(timer.checklist.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                TextField("Adicionar uma tarefa rápida…", text: $newItem)
                    .submitLabel(.done)
                    .onSubmit(addItem)
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(accent)
                }
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)

            ForEach($timer.checklist) { $item in
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.snappy) { item.isDone.toggle() }
                    } label: {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(item.isDone ? accent : .secondary)
                    }
                    Text(item.title)
                        .strikethrough(item.isDone)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                    Spacer()
                    Button {
                        withAnimation { timer.removeChecklistItem(id: item.id) }
                    } label: {
                        Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func addItem() {
        timer.addChecklistItem(newItem)
        newItem = ""
    }

    // MARK: Toast

    @ViewBuilder
    private var logToast: some View {
        if let message = timer.lastLogMessage {
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular.tint(.green.opacity(0.6)), in: .capsule)
                .foregroundStyle(.white)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { timer.lastLogMessage = nil }
                }
        }
    }
}

/// "Foco   25 min  [− +]" – label on the left, value and stepper on the right.
private struct StepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    init(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) {
        self.title = title
        self._value = value
        self.range = range
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value) min")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Stepper("", value: $value, in: range)
                .labelsHidden()
        }
    }
}

/// 60 ticks around a circle; the first `progress × 60` glow in the tint colour.
private struct TickRing: View {
    let progress: Double
    let tint: Color
    let size: CGFloat

    var body: some View {
        let lit = Int((min(1, max(0, progress)) * 60).rounded(.down))
        ZStack {
            ForEach(0..<60, id: \.self) { index in
                let major = index % 5 == 0
                Capsule()
                    .fill(index < lit ? tint : Color.primary.opacity(0.16))
                    .frame(width: major ? 3.5 : 2.5, height: major ? 16 : 9)
                    .shadow(color: index < lit ? tint.opacity(0.7) : .clear, radius: 4)
                    .offset(y: -(size / 2 - 12))
                    .rotationEffect(.degrees(Double(index) * 6))
            }
        }
        .animation(.easeOut(duration: 0.25), value: lit)
    }
}
