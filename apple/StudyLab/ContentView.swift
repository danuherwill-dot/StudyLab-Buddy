import SwiftUI
import SwiftData

/// The five areas of the app (sidebar on Mac, tab bar on iPhone).
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case study, timetable, tasks, stats, grades

    var id: String { rawValue }

    var title: String {
        switch self {
        case .study: "Estudo"
        case .timetable: "Horário"
        case .tasks: "Tarefas"
        case .stats: "Estatísticas"
        case .grades: "Notas"
        }
    }

    var systemImage: String {
        switch self {
        case .study: "timer"
        case .timetable: "calendar"
        case .tasks: "checklist"
        case .stats: "chart.bar.xaxis"
        case .grades: "graduationcap"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var timer
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var selection: AppSection =
        AppSection(rawValue: ProcessInfo.processInfo.environment["STUDYLAB_TAB"] ?? "") ?? .study

    var body: some View {
        platformBody
            .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
            .onAppear {
                timer.configure(context: modelContext)
                #if os(iOS)
                WatchBridge.shared.start(context: modelContext)
                #endif
                #if DEBUG
                DebugTools.seedDemoDataIfRequested(modelContext)
                #if os(macOS)
                DebugTools.scheduleSnapshotIfRequested()
                #endif
                #endif
                Task { await NotificationManager.shared.requestAuthorization() }
            }
    }

    @ViewBuilder
    private var platformBody: some View {
        #if os(macOS)
        NavigationSplitView {
            sidebar
        } detail: {
            page(selection)
                .id(selection)
        }
        .frame(minWidth: 900, minHeight: 640)
        #else
        TabView(selection: $selection) {
            ForEach(AppSection.allCases) { section in
                Tab(section.title, systemImage: section.systemImage, value: section) { page(section) }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        #endif
    }

    @ViewBuilder
    private func page(_ section: AppSection) -> some View {
        switch section {
        case .study: StudyHubView()
        case .timetable: TimetableView()
        case .tasks: TasksView()
        case .stats: StatsView()
        case .grades: GradesView()
        }
    }

    #if os(macOS)
    private var sidebar: some View {
        List(AppSection.allCases, selection: Binding<AppSection?>(get: { selection }, set: { newValue in if let newValue { selection = newValue } })) { section in
            Label(section.title, systemImage: section.systemImage)
                .font(.body.weight(.medium))
                .padding(.vertical, 3)
                .tag(section)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(LinearGradient(colors: [Color(hex: "#4F6DF2"), Color(hex: "#8B5CF6")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 9))
                Text("StudyLab Buddy").font(.title3.weight(.bold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
    }
    #endif
}
