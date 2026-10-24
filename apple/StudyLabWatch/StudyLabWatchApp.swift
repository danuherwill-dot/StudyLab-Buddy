import SwiftUI
import UserNotifications

@main
struct StudyLabWatchApp: App {
    @State private var link = ConnectivityManager()
    @State private var timer = WatchTimer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(link)
                .environment(timer)
                .environment(\.locale, .pt)
                .onAppear {
                    timer.onLog = { link.send($0) }
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        timer.reconcile()
                        link.requestSnapshot()
                    }
                }
        }
    }
}
