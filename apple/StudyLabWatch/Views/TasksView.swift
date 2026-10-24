import SwiftUI

struct TasksView: View {
    @Environment(ConnectivityManager.self) private var link

    private var tasks: [WatchTask] {
        (link.snapshot?.tasks ?? []).sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            return $0.due < $1.due
        }
    }

    private func dueText(_ task: WatchTask) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now),
                                                   to: Calendar.current.startOfDay(for: task.due)).day ?? 0
        if !task.isCompleted && task.due < .now { return days == 0 ? "Em atraso" : "Em atraso \(-days)d" }
        switch days {
        case 0: return "Hoje"
        case 1: return "Amanhã"
        case 2...6: return task.due.formatted(.dateTime.weekday(.wide).locale(.pt))
        default: return task.due.formatted(.dateTime.day().month(.abbreviated).locale(.pt))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if link.snapshot == nil {
                    Text("Abre o StudyLab Buddy no iPhone para sincronizar as tarefas.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else if tasks.isEmpty {
                    Label("Tudo em dia", systemImage: "checkmark.seal").foregroundStyle(.secondary)
                }
                ForEach(tasks) { task in
                    let color = Color(hex: task.colorHex)
                    Button {
                        link.toggle(task)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title).font(.footnote.weight(.semibold)).lineLimit(2)
                                    .strikethrough(task.isCompleted)
                                Text([dueText(task), task.subjectName].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .opacity(task.isCompleted ? 0.6 : 1)
                }
            }
            .navigationTitle("Tarefas")
            .containerBackground(.teal.gradient, for: .navigation)
        }
    }
}
