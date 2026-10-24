import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            StudyView()
            TodayView()
            TasksView()
        }
        .tabViewStyle(.verticalPage)
    }
}
