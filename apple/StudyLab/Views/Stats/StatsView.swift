import SwiftUI
import SwiftData
import Charts

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week, month, year

    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: "Semana"
        case .month: "Mês"
        case .year: "Ano"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    /// Size of each bar in the time chart.
    var bucket: Calendar.Component { self == .year ? .month : .day }
}

struct TimeBucket: Identifiable {
    let date: Date
    let hours: Double
    var id: Date { date }
}

struct SubjectSlice: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let color: Color
    let hours: Double
}

private struct TypeCompletion: Identifiable {
    let type: TaskType
    let done: Int
    let total: Int
    var id: TaskType { type }
    var percent: Double { total == 0 ? 0 : Double(done) / Double(total) * 100 }
}

struct StatsView: View {
    @Query(sort: \StudySession.dateCompleted) private var sessions: [StudySession]
    @Query(sort: \Subject.name) private var subjects: [Subject]
    @Query private var tasks: [StudyTask]

    @State private var period: StatsPeriod = .week
    @State private var offset = 0
    @State private var breakdownAsPie = true
    @State private var showShare = false

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2          // weeks start on Monday
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    // MARK: Data

    private func interval(for period: StatsPeriod, offset: Int) -> DateInterval {
        let base = calendar.date(byAdding: period.component, value: offset, to: .now) ?? .now
        return calendar.dateInterval(of: period.component, for: base) ?? DateInterval(start: base, duration: 86_400)
    }

    private var currentInterval: DateInterval { interval(for: period, offset: offset) }

    private var periodSessions: [StudySession] {
        sessions.filter { currentInterval.contains($0.dateCompleted) }
    }

    private var totalSeconds: Int { periodSessions.reduce(0) { $0 + $1.durationInSeconds } }

    private var buckets: [TimeBucket] {
        let unit = period.bucket
        var totals: [Date: Double] = [:]
        var cursor = currentInterval.start
        while cursor < currentInterval.end {
            totals[cursor] = 0
            guard let next = calendar.date(byAdding: unit, value: 1, to: cursor) else { break }
            cursor = next
        }
        for session in periodSessions {
            if let key = calendar.dateInterval(of: unit, for: session.dateCompleted)?.start {
                totals[key, default: 0] += Double(session.durationInSeconds) / 3600
            }
        }
        return totals.map { TimeBucket(date: $0.key, hours: $0.value) }.sorted { $0.date < $1.date }
    }

    private func slices(for sessions: [StudySession]) -> [SubjectSlice] {
        subjects.compactMap { subject in
            let seconds = sessions
                .filter { $0.subject?.persistentModelID == subject.persistentModelID }
                .reduce(0) { $0 + $1.durationInSeconds }
            guard seconds > 0 else { return nil }
            return SubjectSlice(id: subject.persistentModelID, name: subject.name,
                                color: subject.color, hours: Double(seconds) / 3600)
        }
    }

    private var periodTasks: [StudyTask] {
        tasks.filter { currentInterval.contains($0.dueDate) }
    }

    private var typeCompletions: [TypeCompletion] {
        TaskType.allCases.map { type in
            let ofType = periodTasks.filter { $0.type == type }
            return TypeCompletion(type: type, done: ofType.filter(\.isCompleted).count, total: ofType.count)
        }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Período", selection: $period) {
                        ForEach(StatsPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: period) { offset = 0 }

                    cards
                }
                .padding()
                .readableWidth(1100)
            }
            .pageBackground()
            .navigationTitle("Estatísticas")
            .toolbar {
                ToolbarItem(placement: .trailingBar) {
                    Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }
                }
            }
            .sheet(isPresented: $showShare) { ShareReportSheet(baseData: reportData).formSheet() }
        }
    }

    // MARK: Cards

    /// One column on iPhone; a responsive grid of cards on Mac.
    @ViewBuilder
    private var cards: some View {
        #if os(macOS)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 440), spacing: 16, alignment: .top)], spacing: 16) {
            timeCard
            subjectCard
            weeklyGoalsCard
            completionCard
        }
        #else
        timeCard
        subjectCard
        weeklyGoalsCard
        completionCard
        #endif
    }

    private var periodTitle: String {
        let start = currentInterval.start
        let end = currentInterval.end.addingTimeInterval(-1)
        switch period {
        case .week:
            return "\(start.formatted(.dateTime.day().month(.abbreviated).locale(.pt))) – \(end.formatted(.dateTime.day().month(.abbreviated).locale(.pt)))"
        case .month:
            return start.formatted(.dateTime.month(.wide).year().locale(.pt))
        case .year:
            return start.formatted(.dateTime.year().locale(.pt))
        }
    }

    private var axisFormat: Date.FormatStyle {
        switch period {
        case .week: .dateTime.weekday(.narrow).locale(.pt)
        case .month: .dateTime.day().locale(.pt)
        case .year: .dateTime.month(.narrow).locale(.pt)
        }
    }

    private var timeCard: some View {
        card {
            HStack {
                Button { offset -= 1 } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(periodTitle).font(.headline)
                Spacer()
                Button { offset += 1 } label: { Image(systemName: "chevron.right") }
                    .disabled(offset >= 0)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(DurationFormat.short(seconds: totalSeconds))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("de estudo").foregroundStyle(.secondary)
                Spacer()
                Text(periodSessions.count == 1 ? "1 sessão" : "\(periodSessions.count) sessões").font(.subheadline).foregroundStyle(.secondary)
            }

            Chart(buckets) { bucket in
                BarMark(x: .value("Data", bucket.date, unit: period.bucket),
                        y: .value("Horas", bucket.hours))
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(3)
            }
            .chartYAxisLabel("horas")
            .chartXAxis {
                AxisMarks(values: .stride(by: period.bucket, count: period == .month ? 5 : 1)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: axisFormat, centered: period != .month)
                }
            }
            .frame(height: 180)
        }
    }

    private var subjectCard: some View {
        let data = slices(for: periodSessions)
        return card {
            HStack {
                Text("Por disciplina").font(.headline)
                Spacer()
                Picker("Estilo", selection: $breakdownAsPie) {
                    Image(systemName: "chart.pie").tag(true)
                    Image(systemName: "chart.bar").tag(false)
                }
                .pickerStyle(.segmented)
                    .labelsHidden()
                .frame(width: 100)
            }

            if data.isEmpty {
                emptyNote("Sem sessões de estudo neste período.")
            } else if breakdownAsPie {
                Chart(data) { slice in
                    SectorMark(angle: .value("Horas", slice.hours),
                               innerRadius: .ratio(0.62),
                               angularInset: 1.5)
                        .cornerRadius(4)
                        .foregroundStyle(by: .value("Disciplina", slice.name))
                }
                .chartForegroundStyleScale(domain: data.map(\.name), range: data.map(\.color))
                .chartLegend(position: .bottom, spacing: 12)
                .chartBackground { _ in
                    VStack {
                        Text(DurationFormat.hours(Double(totalSeconds) / 3600)).font(.title3.bold())
                        Text("total").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 260)
            } else {
                Chart(data) { slice in
                    BarMark(x: .value("Horas", slice.hours), y: .value("Disciplina", slice.name))
                        .foregroundStyle(by: .value("Disciplina", slice.name))
                        .cornerRadius(4)
                        .annotation(position: .trailing) {
                            Text(DurationFormat.hours(slice.hours)).font(.caption).foregroundStyle(.secondary)
                        }
                }
                .chartForegroundStyleScale(domain: data.map(\.name), range: data.map(\.color))
                .chartLegend(.hidden)
                .frame(height: CGFloat(max(1, data.count)) * 44 + 20)
            }
        }
    }

    private var weeklyGoalsCard: some View {
        let week = interval(for: .week, offset: 0)
        let thisWeek = sessions.filter { week.contains($0.dateCompleted) }
        let goals = subjects.filter { $0.targetHours > 0 }
        return card {
            Text("Esta semana vs. meta").font(.headline)
            if goals.isEmpty {
                emptyNote("Define uma meta semanal numa disciplina para a acompanhares aqui.")
            } else {
                ForEach(goals) { subject in
                    let hours = Double(thisWeek
                        .filter { $0.subject?.persistentModelID == subject.persistentModelID }
                        .reduce(0) { $0 + $1.durationInSeconds }) / 3600
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(subject.name).font(.subheadline)
                            Spacer()
                            Text("\(DurationFormat.hours(hours)) / \(DurationFormat.hours(subject.targetHours))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: min(hours, subject.targetHours), total: subject.targetHours)
                            .tint(subject.color)
                    }
                }
            }
        }
    }

    private var completionCard: some View {
        let total = periodTasks.count
        let done = periodTasks.filter(\.isCompleted).count
        let percent = total == 0 ? 0 : Double(done) / Double(total) * 100
        return card {
            Text("Tarefas concluídas").font(.headline)
            if total == 0 {
                emptyNote("Não há tarefas com entrega neste período.")
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(percent.rounded()))%")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("\(done) de \(total) concluídas").foregroundStyle(.secondary)
                }
                ProgressView(value: Double(done), total: Double(total)).tint(.green)

                Chart(typeCompletions.filter { $0.total > 0 }) { item in
                    BarMark(x: .value("Tipo", item.type.pluralTitle), y: .value("Concluídas", item.percent))
                        .foregroundStyle(.green.gradient)
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            Text("\(Int(item.percent.rounded()))%").font(.caption).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: 0...115)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel { if let v = value.as(Int.self) { Text("\(v)%") } }
                    }
                }
                .frame(height: 160)
            }
        }
    }

    private var reportData: ReportData {
        ReportData(periodTitle: periodTitle,
                   totalSeconds: totalSeconds,
                   sessionCount: periodSessions.count,
                   buckets: buckets,
                   bucketUnit: period.bucket,
                   axisFormat: axisFormat,
                   slices: slices(for: periodSessions),
                   tasksDone: periodTasks.filter(\.isCompleted).count,
                   tasksTotal: periodTasks.count)
    }

    // MARK: Helpers

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 60)
    }
}
