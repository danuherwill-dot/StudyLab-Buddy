import SwiftUI
import SwiftData

enum TaskFilter: String, CaseIterable, Identifiable {
    case all, homework, tests, assignments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Todas"
        case .homework: "TPC"
        case .tests: "Testes"
        case .assignments: "Trabalhos"
        }
    }

    func matches(_ task: StudyTask) -> Bool {
        switch self {
        case .all: true
        case .homework: task.type == .homework
        case .tests: task.type == .test
        case .assignments: task.type == .assignment
        }
    }
}

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyTask.dueDate) private var tasks: [StudyTask]

    @State private var filter: TaskFilter = .all
    @State private var editor: TaskEditorTarget?

    private var calendar: Calendar { .current }
    private var filtered: [StudyTask] { tasks.filter(filter.matches) }
    private var openTasks: [StudyTask] { filtered.filter { !$0.isCompleted } }
    private var overdue: [StudyTask] { openTasks.filter(\.isOverdue) }
    private var today: [StudyTask] {
        openTasks.filter { !$0.isOverdue && calendar.isDateInToday($0.dueDate) }
    }
    private var thisWeek: [StudyTask] {
        let end = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: .now)) ?? .now
        return openTasks.filter { !$0.isOverdue && !calendar.isDateInToday($0.dueDate) && $0.dueDate < end }
    }
    private var later: [StudyTask] {
        let end = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: .now)) ?? .now
        return openTasks.filter { $0.dueDate >= end }
    }
    private var completed: [StudyTask] { filtered.filter(\.isCompleted).reversed() }

    var body: some View {
        NavigationStack {
            List {
                summary
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                filterChips
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                section("Em atraso", overdue, tint: .red)
                section("Hoje", today, tint: .accentColor)
                section("Esta semana", thisWeek)
                section("Mais tarde", later)
                section("Concluídas", completed)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .readableWidth(820)
            .pageBackground()
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView("Tudo em dia", systemImage: "checkmark.seal",
                                           description: Text("Toca em + para adicionar TPC, um teste ou um trabalho."))
                }
            }
            .navigationTitle("Tarefas")
            .toolbar {
                ToolbarItem(placement: .trailingBar) {
                    Button { editor = TaskEditorTarget() } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editor) { target in
                NavigationStack { TaskFormView(target: target) }
                    .formSheet()
            }
        }
    }

    // MARK: Summary

    private var summary: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                tile(overdue.count, "Em atraso", systemImage: "exclamationmark.circle.fill", tint: .red)
                tile(today.count, "Hoje", systemImage: "sun.max.fill", tint: .orange)
                tile(thisWeek.count, "Esta semana", systemImage: "calendar", tint: .accentColor)
            }
        }
    }

    private func tile(_ value: Int, _ title: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(tint).font(.title3).frame(height: 26)
            Text("\(value)").font(.system(size: 30, weight: .bold, design: .rounded)).contentTransition(.numericText())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(TaskFilter.allCases) { option in
                        let selected = option == filter
                        Button {
                            withAnimation(.snappy) { filter = option }
                        } label: {
                            Text(option.title)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .glassEffect(selected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                                             in: .capsule)
                                .foregroundStyle(selected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func section(_ title: String, _ items: [StudyTask], tint: Color = .secondary) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { task in
                    TaskCard(task: task, onToggle: { toggle(task) })
                        .contentShape(Rectangle())
                        .onTapGesture { editor = TaskEditorTarget(task: task) }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { delete(task) } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                }
            } header: {
                HStack(spacing: 8) {
                    Text(title).font(.headline).foregroundStyle(tint == .secondary ? .primary : tint)
                    Text("\(items.count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(.primary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                .textCase(nil)
            }
        }
    }

    private func toggle(_ task: StudyTask) {
        withAnimation(.snappy) {
            task.isCompleted.toggle()
        }
        try? modelContext.save()
        Task { await NotificationManager.shared.scheduleReminders(for: task) }
    }

    private func delete(_ task: StudyTask) {
        NotificationManager.shared.cancelReminders(for: task)
        withAnimation { modelContext.delete(task) }
        try? modelContext.save()
    }
}

private struct TaskCard: View {
    let task: StudyTask
    let onToggle: () -> Void

    private var calendar: Calendar { .current }

    private var accent: Color { task.subject?.color ?? .accentColor }

    private var dueLabel: String {
        let due = calendar.startOfDay(for: task.dueDate)
        let todayStart = calendar.startOfDay(for: .now)
        let days = calendar.dateComponents([.day], from: todayStart, to: due).day ?? 0
        if task.isOverdue { return days == 0 ? "Em atraso" : "Em atraso \(-days)d" }
        switch days {
        case 0: return "Hoje"
        case 1: return "Amanhã"
        case 2...6: return task.dueDate.formatted(.dateTime.weekday(.wide).locale(.pt))
        default: return task.dueDate.formatted(.dateTime.day().month(.abbreviated).locale(.pt))
        }
    }

    private var dueColor: Color {
        if task.isCompleted { return .secondary }
        if task.isOverdue { return .red }
        return calendar.isDateInToday(task.dueDate) ? .orange : .primary
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                ZStack {
                    Circle().strokeBorder(accent, lineWidth: 2)
                    if task.isCompleted {
                        Circle().fill(accent)
                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: task.isCompleted)

            VStack(alignment: .leading, spacing: 7) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                HStack(spacing: 8) {
                    if let subject = task.subject {
                        HStack(spacing: 5) {
                            Circle().fill(subject.color).frame(width: 7, height: 7)
                            Text(subject.name)
                        }
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(subject.color.opacity(0.18), in: Capsule())
                    }
                    Label(task.type.title, systemImage: task.type.systemImage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(dueLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(dueColor)
                HStack(spacing: 4) {
                    if task.remindMe && !task.isCompleted {
                        Image(systemName: "bell.fill")
                    }
                    Text(task.dueDate, format: .dateTime.hour().minute())
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .opacity(task.isCompleted ? 0.7 : 1)
    }
}

struct TaskEditorTarget: Identifiable {
    let id = UUID()
    var task: StudyTask?
}

struct TaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]

    let target: TaskEditorTarget

    @State private var title: String
    @State private var subject: Subject?
    @State private var type: TaskType
    @State private var dueDate: Date
    @State private var remindMe: Bool

    init(target: TaskEditorTarget) {
        self.target = target
        let task = target.task
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        _title = State(initialValue: task?.title ?? "")
        _subject = State(initialValue: task?.subject)
        _type = State(initialValue: task?.type ?? .homework)
        _dueDate = State(initialValue: task?.dueDate ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow)
        _remindMe = State(initialValue: task?.remindMe ?? true)
    }

    var body: some View {
        Form {
            Section {
                TextField("Título", text: $title)
                Picker("Tipo", selection: $type) {
                    ForEach(TaskType.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                SubjectPickerField(selection: $subject, subjects: subjects, allowsNone: true)
            }
            Section {
                DatePicker("Entrega", selection: $dueDate)
                Toggle("Lembrar-me", isOn: $remindMe)
            } footer: {
                Text(reminderFootnote)
            }
            if let task = target.task {
                Section {
                    Button("Eliminar tarefa", role: .destructive) {
                        NotificationManager.shared.cancelReminders(for: task)
                        modelContext.delete(task)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(target.task == nil ? "Nova tarefa" : "Editar tarefa")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar", action: save)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var reminderFootnote: String {
        guard remindMe else { return "" }
        switch type {
        case .homework: return "Lembretes: 1 dia antes, 1 hora antes e à hora de entrega."
        case .assignment: return "Lembretes: 3 dias antes, 1 dia antes e à hora de entrega."
        case .test: return "Lembretes: 1 semana, 3 dias, 1 dia e 2 horas antes do teste."
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let task: StudyTask
        if let existing = target.task {
            existing.title = trimmed
            existing.subject = subject
            existing.type = type
            existing.dueDate = dueDate
            existing.remindMe = remindMe
            task = existing
        } else {
            task = StudyTask(title: trimmed, subject: subject, type: type, dueDate: dueDate, remindMe: remindMe)
            modelContext.insert(task)
        }
        try? modelContext.save()
        Task { await NotificationManager.shared.scheduleReminders(for: task) }
        dismiss()
    }
}
