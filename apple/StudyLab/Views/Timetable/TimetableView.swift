import SwiftUI
import SwiftData

struct TimetableEditorTarget: Identifiable {
    let id = UUID()
    var entry: TimetableEntry?
    var day: Weekday = .monday
    var startTime: Int = 8 * 60
}

struct TimetableView: View {
    private enum Mode: String, CaseIterable {
        case week = "Semana", day = "Dia"
    }

    @Query(sort: [SortDescriptor(\TimetableEntry.startTime)]) private var entries: [TimetableEntry]
    @AppStorage("timetableShowWeekend") private var showWeekend = false
    @State private var editor: TimetableEditorTarget?
    @State private var mode: Mode = .week
    @State private var selectedDay: Weekday = .today

    private let hourHeight: CGFloat = 64
    private let gutterWidth: CGFloat = 34

    // MARK: Derived

    private var hasWeekendEntries: Bool {
        entries.contains { $0.dayOfWeek == .saturday || $0.dayOfWeek == .sunday }
    }

    private var days: [Weekday] {
        (showWeekend || hasWeekendEntries) ? Weekday.allCases : Weekday.schoolDays
    }

    private var activeDay: Weekday { days.contains(selectedDay) ? selectedDay : .monday }

    private var firstHour: Int {
        min(8, (entries.map(\.startTime).min() ?? 8 * 60) / 60)
    }

    private var lastHour: Int {
        let latest = Int(ceil(Double(entries.map(\.endTime).max() ?? 17 * 60) / 60))
        return min(24, max(17, latest))
    }

    private var hours: [Int] { Array(firstHour..<lastHour) }

    private var weekStart: Date {
        Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }

    private func date(for day: Weekday) -> Date {
        Calendar.current.date(byAdding: .day, value: day.rawValue - 1, to: weekStart) ?? .now
    }

    private func minutes(of date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                    .labelsHidden()
                .padding(.horizontal)

                dayHeader

                switch mode {
                case .week: weekGrid
                case .day: dayList
                }
            }
            .padding(.top, 4)
            .pageBackground()
            .navigationTitle("Horário")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .leadingBar) {
                    Menu {
                        Toggle("Mostrar fim de semana", isOn: $showWeekend)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
                ToolbarItem(placement: .trailingBar) {
                    Button {
                        let day = mode == .day ? activeDay : (Weekday.schoolDays.contains(.today) ? .today : .monday)
                        editor = TimetableEditorTarget(day: day)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editor) { target in
                NavigationStack { TimetableEntryFormView(target: target) }
                    .formSheet()
            }
        }
    }

    // MARK: Header

    private var dayHeader: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                if mode == .week { Color.clear.frame(width: gutterWidth - 6, height: 1) }
                ForEach(days) { day in
                    let isToday = day == .today
                    let isSelected = mode == .day && day == activeDay
                    Button {
                        withAnimation(.snappy) { selectedDay = day; mode = .day }
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.shortName.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .secondary))
                            Text(date(for: day), format: .dateTime.day())
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(isSelected || (isToday && mode == .week) ? .white : .primary)
                                .frame(width: 30, height: 30)
                                .background {
                                    if isToday && mode == .week { Circle().fill(Color.accentColor) }
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .glassEffect(isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                                     in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: Week grid

    private var weekGrid: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 6) {
                hourGutter
                ForEach(days) { day in
                    dayColumn(day)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("Ainda sem aulas", systemImage: "calendar.badge.plus",
                                       description: Text("Toca em + ou num espaço vazio para adicionar uma aula."))
                    .allowsHitTesting(false)
            }
        }
    }

    private var hourGutter: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: gutterWidth - 6, height: hourHeight, alignment: .top)
                    .offset(y: -6)
            }
        }
    }

    private func dayColumn(_ day: Weekday) -> some View {
        let dayEntries = entries.filter { $0.dayOfWeek == day }
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(hours, id: \.self) { _ in
                    Rectangle().fill(.clear).frame(height: hourHeight)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.5)
                        }
                }
            }
            .background(day == .today ? Color.accentColor.opacity(0.06) : .clear,
                        in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture { location in
                let hour = firstHour + min(hours.count - 1, max(0, Int(location.y / hourHeight)))
                editor = TimetableEditorTarget(day: day, startTime: hour * 60)
            }

            ForEach(dayEntries) { entry in
                block(for: entry)
            }

            if day == .today { nowLine }
        }
        .frame(maxWidth: .infinity)
        .frame(height: hourHeight * CGFloat(hours.count))
    }

    private var nowLine: some View {
        TimelineView(.everyMinute) { context in
            let now = minutes(of: context.date)
            if now >= firstHour * 60 && now < lastHour * 60 {
                HStack(spacing: 0) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Rectangle().fill(.red).frame(height: 1.5)
                }
                .offset(y: CGFloat(now - firstHour * 60) / 60 * hourHeight - 3)
            }
        }
        .allowsHitTesting(false)
    }

    private func block(for entry: TimetableEntry) -> some View {
        let top = CGFloat(entry.startTime - firstHour * 60) / 60 * hourHeight
        let height = max(26, CGFloat(entry.endTime - entry.startTime) / 60 * hourHeight)
        let color = entry.subject?.color ?? .gray
        return HStack(spacing: 0) {
            Rectangle().fill(color).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.subject?.name ?? "—")
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(2)
                if !entry.room.isEmpty && height > 44 {
                    Text(entry.room)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height - 3, alignment: .topLeading)
        .background(color.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .offset(y: top + 1.5)
        .onTapGesture { editor = TimetableEditorTarget(entry: entry) }
    }

    // MARK: Day list

    private var dayList: some View {
        let dayEntries = entries.filter { $0.dayOfWeek == activeDay }
        return ScrollView {
            LazyVStack(spacing: 10) {
                if dayEntries.isEmpty {
                    ContentUnavailableView {
                        Label("Sem aulas: \(activeDay.fullName)", systemImage: "moon.stars")
                    } description: {
                        Text("Aproveita o tempo livre ou adiciona uma aula.")
                    } actions: {
                        Button("Adicionar aula") { editor = TimetableEditorTarget(day: activeDay) }
                            .buttonStyle(.glassProminent)
                    }
                    .padding(.top, 40)
                }
                ForEach(dayEntries) { entry in
                    dayCard(entry)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func dayCard(_ entry: TimetableEntry) -> some View {
        let color = entry.subject?.color ?? .gray
        let now = minutes(of: .now)
        let isNow = activeDay == .today && now >= entry.startTime && now < entry.endTime
        return HStack(spacing: 14) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(TimetableEntry.text(minutes: entry.startTime)).font(.subheadline.weight(.semibold))
                Text(TimetableEntry.text(minutes: entry.endTime)).font(.caption).foregroundStyle(.secondary)
            }
            .monospacedDigit()
            .frame(width: 48)

            Capsule().fill(color).frame(width: 4)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.subject?.name ?? "—").font(.headline)
                HStack(spacing: 12) {
                    if !entry.room.isEmpty {
                        Label(entry.room, systemImage: "mappin.and.ellipse")
                    }
                    Label(DurationFormat.short(seconds: (entry.endTime - entry.startTime) * 60), systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if isNow {
                Text("AGORA")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .contentShape(Rectangle())
        .onTapGesture { editor = TimetableEditorTarget(entry: entry) }
    }
}

struct TimetableEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]

    let target: TimetableEditorTarget

    @State private var subject: Subject?
    @State private var day: Weekday
    @State private var start: Date
    @State private var end: Date
    @State private var room: String

    init(target: TimetableEditorTarget) {
        self.target = target
        let entry = target.entry
        _subject = State(initialValue: entry?.subject)
        _day = State(initialValue: entry?.dayOfWeek ?? target.day)
        let startMinutes = entry?.startTime ?? target.startTime
        let endMinutes = entry?.endTime ?? min(startMinutes + 60, 24 * 60 - 1)
        _start = State(initialValue: Self.date(minutes: startMinutes))
        _end = State(initialValue: Self.date(minutes: endMinutes))
        _room = State(initialValue: entry?.room ?? "")
    }

    private static func date(minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }

    private static func minutes(of date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private var isValid: Bool {
        subject != nil && Self.minutes(of: end) > Self.minutes(of: start)
    }

    var body: some View {
        Form {
            Section {
                if subjects.isEmpty {
                    NavigationLink("Cria a tua primeira disciplina") { SubjectFormView(subject: nil) }
                } else {
                    SubjectPickerField(selection: $subject, subjects: subjects)
                }
            }
            Section {
                Picker("Dia", selection: $day) {
                    ForEach(Weekday.allCases) { Text($0.fullName).tag($0) }
                }
                DatePicker("Início", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("Fim", selection: $end, displayedComponents: .hourAndMinute)
                TextField("Sala (opcional)", text: $room)
            } footer: {
                if Self.minutes(of: end) <= Self.minutes(of: start) {
                    Text("A hora de fim tem de ser posterior à hora de início.").foregroundStyle(.red)
                }
            }
            if let entry = target.entry {
                Section {
                    Button("Eliminar aula", role: .destructive) {
                        modelContext.delete(entry)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(target.entry == nil ? "Nova aula" : "Editar aula")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar", action: save).disabled(!isValid)
            }
        }
    }

    private func save() {
        let startMinutes = Self.minutes(of: start)
        let endMinutes = Self.minutes(of: end)
        let trimmedRoom = room.trimmingCharacters(in: .whitespaces)
        if let entry = target.entry {
            entry.subject = subject
            entry.dayOfWeek = day
            entry.startTime = startMinutes
            entry.endTime = endMinutes
            entry.room = trimmedRoom
        } else {
            modelContext.insert(TimetableEntry(subject: subject, dayOfWeek: day,
                                               startTime: startMinutes, endTime: endMinutes, room: trimmedRoom))
        }
        try? modelContext.save()
        dismiss()
    }
}
