import SwiftUI
import SwiftData
import Charts

struct ReportGradeLine: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let average: String
    let passing: Bool
}

struct ReportData {
    var periodTitle: String
    var totalSeconds: Int
    var sessionCount: Int
    var buckets: [TimeBucket]
    var bucketUnit: Calendar.Component
    var axisFormat: Date.FormatStyle
    var slices: [SubjectSlice]
    var tasksDone: Int
    var tasksTotal: Int
    var gradeLines: [ReportGradeLine] = []
    var overallGrade: String?
    var gradeScaleNote: String = ""

    var taskPercent: Int { tasksTotal == 0 ? 0 : Int((Double(tasksDone) / Double(tasksTotal) * 100).rounded()) }

    func summaryText(studentName: String) -> String {
        var lines = ["📚 Relatório StudyLab" + (studentName.isEmpty ? "" : " – \(studentName)"), periodTitle, ""]
        lines.append("⏱ Estudo: \(DurationFormat.short(seconds: totalSeconds)) em \(sessionCount) sessões")
        for slice in slices.sorted(by: { $0.hours > $1.hours }) {
            lines.append("  • \(slice.name): \(DurationFormat.hours(slice.hours))")
        }
        if tasksTotal > 0 { lines.append("✅ Tarefas concluídas: \(tasksDone)/\(tasksTotal) (\(taskPercent)%)") }
        if !gradeLines.isEmpty {
            lines.append("")
            lines.append("🎓 Notas (\(gradeScaleNote))")
            if let overallGrade { lines.append("  Média geral: \(overallGrade)") }
            for g in gradeLines { lines.append("  • \(g.name): \(g.average)") }
        }
        return lines.joined(separator: "\n")
    }
}

/// Plain, light-only card that is rendered to an image for sharing.
struct ReportCardView: View {
    let data: ReportData
    let studentName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("StudyLab").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.white.opacity(0.8))
                Text(studentName.isEmpty ? "Relatório de estudo" : "Relatório de estudo de \(studentName)")
                    .font(.title2.bold()).foregroundStyle(.white)
                Text(data.periodTitle).font(.subheadline).foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(LinearGradient(colors: [Color(hex: "#4F6DF2"), Color(hex: "#8B5CF6")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    stat("Tempo de estudo", DurationFormat.short(seconds: data.totalSeconds))
                    stat("Sessões", "\(data.sessionCount)")
                    stat("Tarefas feitas", data.tasksTotal == 0 ? "—" : "\(data.taskPercent)%")
                }

                Chart(data.buckets) { b in
                    BarMark(x: .value("Data", b.date, unit: data.bucketUnit), y: .value("Horas", b.hours))
                        .foregroundStyle(Color(hex: "#4F6DF2").gradient)
                        .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: data.bucketUnit, count: data.buckets.count > 14 ? 5 : 1)) { _ in
                        AxisValueLabel(format: data.axisFormat, centered: data.buckets.count <= 14)
                    }
                }
                .chartYAxisLabel("horas")
                .frame(height: 130)

                if !data.slices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Por disciplina").font(.headline)
                        let maxHours = data.slices.map(\.hours).max() ?? 1
                        ForEach(data.slices.sorted { $0.hours > $1.hours }) { slice in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(slice.name).font(.subheadline)
                                    Spacer()
                                    Text(DurationFormat.hours(slice.hours)).font(.caption).foregroundStyle(.secondary)
                                }
                                GeometryReader { geo in
                                    Capsule().fill(slice.color)
                                        .frame(width: max(6, geo.size.width * slice.hours / maxHours))
                                }
                                .frame(height: 8)
                            }
                        }
                    }
                }

                if !data.gradeLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notas").font(.headline)
                            Spacer()
                            Text(data.gradeScaleNote).font(.caption).foregroundStyle(.secondary)
                        }
                        if let overall = data.overallGrade {
                            HStack { Text("Média geral").font(.subheadline.bold()); Spacer(); Text(overall).font(.subheadline.bold()) }
                        }
                        ForEach(data.gradeLines) { g in
                            HStack {
                                Circle().fill(g.color).frame(width: 8, height: 8)
                                Text(g.name).font(.subheadline)
                                Spacer()
                                Text(g.average).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(g.passing ? .green : .red)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 360)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        .foregroundStyle(Color.black)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ShareReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @AppStorage("studentName") private var studentName = ""
    @AppStorage("educationLevel") private var levelRaw = EducationLevel.secondary.rawValue
    @State private var includeGrades = false
    @State private var image: Image?

    /// Builds the period data; the sheet adds grades on top.
    let baseData: ReportData

    private var level: EducationLevel { EducationLevel(rawValue: levelRaw) ?? .secondary }

    private var data: ReportData {
        var d = baseData
        guard includeGrades else { return d }
        d.gradeScaleNote = level.scaleDescription
        d.gradeLines = subjects.compactMap { s in
            guard let avg = GradeCalculator.average(for: s, level: level) else { return nil }
            return ReportGradeLine(name: s.name, color: s.color, average: level.format(avg),
                                   passing: GradeCalculator.isPassing(avg, level: level))
        }
        d.overallGrade = GradeCalculator.overallAverage(subjects: subjects, level: level).map(level.format)
        return d
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 0) {
                        TextField("Nome do aluno (opcional)", text: $studentName)
                            .padding(14)
                        Divider()
                        Toggle("Incluir notas", isOn: $includeGrades)
                            .padding(14)
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))

                    ReportCardView(data: data, studentName: studentName)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)

                    if let image {
                        GlassEffectContainer(spacing: 12) {
                            VStack(spacing: 12) {
                                ShareLink(item: image,
                                          preview: SharePreview("Relatório StudyLab", image: image)) {
                                    Label("Partilhar como imagem", systemImage: "photo")
                                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                                }
                                .buttonStyle(.glassProminent)

                                ShareLink(item: data.summaryText(studentName: studentName)) {
                                    Label("Partilhar como texto", systemImage: "text.alignleft")
                                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Partilhar com os pais")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Concluído") { dismiss() } }
            }
            .task(id: renderKey) { render() }
        }
    }

    private var renderKey: String { "\(studentName)|\(includeGrades)|\(levelRaw)|\(subjects.count)" }

    private func render() {
        let renderer = ImageRenderer(content: ReportCardView(data: data, studentName: studentName))
        renderer.scale = max(displayScale, 2)
        #if os(iOS)
        image = renderer.uiImage.map { Image(uiImage: $0) }
        #else
        image = renderer.nsImage.map { Image(nsImage: $0) }
        #endif
    }
}
