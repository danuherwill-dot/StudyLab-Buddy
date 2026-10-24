import SwiftUI

struct TodayView: View {
    @Environment(ConnectivityManager.self) private var link

    private var weekday: Int {
        let w = Calendar.current.component(.weekday, from: .now) // 1 = Sunday
        return w == 1 ? 7 : w - 1
    }

    private var classes: [WatchClass] {
        (link.snapshot?.classes ?? []).filter { $0.weekday == weekday }.sorted { $0.start < $1.start }
    }

    private func text(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: context.date)
                let nowMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
                List {
                    if link.snapshot == nil {
                        Text("Abre o StudyLab Buddy no iPhone para sincronizar o horário.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if classes.isEmpty {
                        Label("Sem aulas hoje", systemImage: "moon.stars")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(classes) { entry in
                        let isNow = nowMinutes >= entry.start && nowMinutes < entry.end
                        let color = Color(hex: entry.colorHex)
                        HStack(spacing: 8) {
                            Capsule().fill(color).frame(width: 4)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.subjectName).font(.headline).lineLimit(1)
                                Text("\(text(entry.start))–\(text(entry.end))" + (entry.room.isEmpty ? "" : " · \(entry.room)"))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if isNow {
                                Text("AGORA").font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(color, in: Capsule())
                            }
                        }
                        .listRowBackground(color.opacity(isNow ? 0.28 : 0.14).clipShape(RoundedRectangle(cornerRadius: 14)))
                    }
                }
            }
            .navigationTitle("Hoje")
            .containerBackground(.indigo.gradient, for: .navigation)
        }
    }
}
