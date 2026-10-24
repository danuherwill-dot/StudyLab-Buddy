import SwiftUI
import SwiftData
import UserNotifications

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Escuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private enum ClearTarget: String, Identifiable {
    case timetable, tasks, grades, sessions, subjects, everything

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timetable: "Apagar o horário?"
        case .tasks: "Apagar todas as tarefas?"
        case .grades: "Apagar todas as notas?"
        case .sessions: "Apagar o histórico de estudo?"
        case .subjects: "Apagar todas as disciplinas?"
        case .everything: "Apagar TODOS os dados?"
        }
    }

    var message: String {
        switch self {
        case .timetable: "Todas as aulas do teu horário serão eliminadas."
        case .tasks: "Todos os TPC, testes e trabalhos serão eliminados e os respetivos lembretes cancelados."
        case .grades: "Todas as notas de teste e de período serão eliminadas."
        case .sessions: "Todas as sessões de estudo registadas serão eliminadas, pelo que as Estatísticas serão repostas."
        case .subjects: "Todas as disciplinas serão eliminadas, juntamente com as aulas, tarefas, notas e sessões de estudo associadas."
        case .everything: "Disciplinas, horário, tarefas, notas e histórico de estudo serão eliminados. Esta ação não pode ser anulada."
        }
    }
}

struct SettingsView: View {
    /// Hidden when the view is shown in the Mac Settings window instead of a sheet.
    var showsDone = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var timer
    @Query private var tasks: [StudyTask]
    @Query private var timetable: [TimetableEntry]
    @Query private var grades: [Grade]
    @Query private var sessions: [StudySession]
    @Query private var subjects: [Subject]

    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(NotificationManager.taskRemindersKey) private var taskReminders = true
    @AppStorage(NotificationManager.timerAlertsKey) private var timerAlerts = true
    @AppStorage(GradeCalculator.weightByDurationKey) private var weightByDuration = true

    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var pendingClear: ClearTarget?

    var body: some View {
        NavigationStack {
            Form {
                Section("Aparência") {
                    Picker("Tema", selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if status == .denied {
                        Label("As notificações do StudyLab estão desativadas nas Definições do sistema.", systemImage: "bell.slash")
                            .foregroundStyle(.orange)
                        Button("Abrir Definições do sistema") {
                            Self.openSystemSettings()
                        }
                    }
                    Toggle("Lembretes de tarefas e testes", isOn: $taskReminders)
                    Toggle("Alertas do temporizador", isOn: $timerAlerts)
                    Button("Enviar notificação de teste") {
                        Task { await NotificationManager.shared.sendTestNotification() }
                    }
                } header: {
                    Text("Notificações")
                } footer: {
                    Text("Os lembretes de tarefas abrangem TPC, trabalhos e testes com “Lembrar-me” ativado. Os alertas do temporizador disparam quando um bloco de foco, uma pausa ou uma contagem termina com a app em segundo plano.")
                }

                Section {
                    Toggle("Ponderar disciplinas pela duração", isOn: $weightByDuration)
                } header: {
                    Text("Média do Secundário")
                } footer: {
                    Text("Ativado: na média do curso, uma disciplina de 3 anos conta ×3, de 2 anos ×2 e de 1 ano ×1 (regras atuais para quem começou o 10.º em 2023/24 ou depois). Desativado: todas as disciplinas contam o mesmo.")
                }

                Section {
                    clearRow("Apagar horário", count: timetable.count, target: .timetable)
                    clearRow("Apagar tarefas", count: tasks.count, target: .tasks)
                    clearRow("Apagar notas", count: grades.count, target: .grades)
                    clearRow("Apagar histórico de estudo", count: sessions.count, target: .sessions)
                    clearRow("Apagar disciplinas", count: subjects.count, target: .subjects)
                } header: {
                    Text("Os teus dados")
                } footer: {
                    Text("Os dados ficam guardados apenas neste dispositivo. Apagar disciplinas também remove tudo o que está associado a elas.")
                }

                Section {
                    Button("Apagar todos os dados", role: .destructive) { pendingClear = .everything }
                        .disabled(subjects.isEmpty && tasks.isEmpty && timetable.isEmpty && grades.isEmpty && sessions.isEmpty)
                }
            }
            .confirmationDialog(pendingClear?.title ?? "", isPresented: Binding(
                get: { pendingClear != nil }, set: { if !$0 { pendingClear = nil } }),
                titleVisibility: .visible, presenting: pendingClear) { target in
                Button("Eliminar", role: .destructive) { clear(target) }
                Button("Cancelar", role: .cancel) {}
            } message: { target in
                Text(target.message)
            }
            .formStyle(.grouped)
        .navigationTitle("Definições")
            .inlineNavigationTitle()
            .toolbar {
                if showsDone {
                    ToolbarItem(placement: .confirmationAction) { Button("Concluído") { dismiss() } }
                }
            }
            .task { await refreshStatus() }
            .onChange(of: scenePhase) { Task { await refreshStatus() } }
            .onChange(of: taskReminders) { _, enabled in
                Task {
                    if enabled {
                        for task in tasks { await NotificationManager.shared.scheduleReminders(for: task) }
                    } else {
                        await NotificationManager.shared.cancelAllTaskReminders()
                    }
                }
            }
            .onChange(of: timerAlerts) { _, enabled in
                if !enabled { NotificationManager.shared.cancelTimerEnd() }
            }
        }
    }

    private func clearRow(_ title: String, count: Int, target: ClearTarget) -> some View {
        Button(role: .destructive) { pendingClear = target } label: {
            HStack {
                Text(title)
                Spacer()
                Text("\(count)").foregroundStyle(.secondary)
            }
        }
        .disabled(count == 0)
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        guard let items = try? modelContext.fetch(FetchDescriptor<T>()) else { return }
        for item in items { modelContext.delete(item) }
    }

    private func clear(_ target: ClearTarget) {
        switch target {
        case .timetable:
            deleteAll(TimetableEntry.self)
        case .tasks:
            tasks.forEach { NotificationManager.shared.cancelReminders(for: $0) }
            deleteAll(StudyTask.self)
        case .grades:
            deleteAll(Grade.self)
        case .sessions:
            deleteAll(StudySession.self)
        case .subjects:
            timer.discard()
            timer.subject = nil
            tasks.forEach { NotificationManager.shared.cancelReminders(for: $0) }
            deleteAll(Subject.self)
        case .everything:
            timer.discard()
            timer.subject = nil
            tasks.forEach { NotificationManager.shared.cancelReminders(for: $0) }
            deleteAll(TimetableEntry.self)
            deleteAll(StudyTask.self)
            deleteAll(Grade.self)
            deleteAll(StudySession.self)
            deleteAll(Subject.self)
        }
        try? modelContext.save()
        pendingClear = nil
    }

    static func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    private func refreshStatus() async {
        status = await NotificationManager.shared.authorizationStatus()
    }
}
