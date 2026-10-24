import SwiftUI
import SwiftData

@main
struct StudyLabApp: App {
    @State private var timer = TimerManager()

    /// Shared by the main window and (on Mac) the Settings window.
    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: Subject.self, StudyTask.self, TimetableEntry.self,
                                      StudySession.self, Grade.self)
        } catch {
            fatalError("Could not create the data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(timer)
                .environment(\.locale, .pt)
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1040, height: 780)
        #endif

        #if os(macOS)
        // ⌘, opens the native Settings window.
        Settings {
            SettingsView(showsDone: false)
                .environment(timer)
                .environment(\.locale, .pt)
                .modelContainer(container)
                .frame(width: 480, height: 640)
        }
        #endif
    }
}
