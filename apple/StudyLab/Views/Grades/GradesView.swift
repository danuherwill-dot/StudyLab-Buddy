import SwiftUI
import SwiftData

struct GradesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @AppStorage("educationLevel") private var levelRaw = EducationLevel.secondary.rawValue
    @State private var editor: GradeEditorTarget?
    @AppStorage("gradesYear") private var year = 10
    @State private var tab: GradesTab = .terms
    @State private var selectedPeriod: Int?
    @State private var showSubjects = false

    private var level: EducationLevel {
        get { EducationLevel(rawValue: levelRaw) ?? .secondary }
        nonmutating set { levelRaw = newValue.rawValue }
    }

    /// Secundário year being viewed; 0 for Básico.
    private var activeYear: Int { level == .secondary ? year : 0 }

    private var period: Int {
        selectedPeriod ?? GradeCalculator.latestTermPeriod(subjects: subjects, level: level, year: activeYear) ?? 1
    }

    /// Básico: mean of the period's term marks. Secundário: the 3-year course average.
    private var overall: Double? {
        GradeCalculator.overallAverage(subjects: subjects, level: level, period: level == .basic ? period : nil)
    }

    private var effectiveTab: GradesTab { tab }

    /// Subjects shown for the current level (and year, in Secundário).
    private var visibleSubjects: [Subject] {
        level == .basic ? subjects : subjects.filter { $0.secondaryYears.contains(year) }
    }

    var body: some View {
        NavigationStack {
            List {
                levelChips.cardRow(top: 4, bottom: 4, horizontal: 16)
                hero.cardRow(top: 6, bottom: 6)
                if subjects.isEmpty {
                    ContentUnavailableView {
                        Label("Ainda sem disciplinas", systemImage: "graduationcap")
                    } description: {
                        Text("Adiciona as tuas disciplinas e regista aqui as tuas notas.")
                    } actions: {
                        Button("Adicionar disciplinas") { showSubjects = true }
                            .buttonStyle(.glassProminent)
                    }
                        .cardRow(top: 30, bottom: 0)
                } else {
                    tabChips.cardRow(top: 4, bottom: 8, horizontal: 0)

                    switch effectiveTab {
                    case .terms:
                        termSection
                    case .history:
                        historySection
                    case .subjects:
                        ForEach(visibleSubjects) { subject in
                            subjectSection(subject)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .readableWidth(820)
            .pageBackground()
            .navigationTitle("Notas")
            .toolbar {
                ToolbarItem(placement: .trailingBar) {
                    if level == .basic {
                        Menu {
                            Button("Adicionar nota de teste", systemImage: "doc.text") {
                                editor = GradeEditorTarget(level: level)
                            }
                            Button("Adicionar nota de período", systemImage: "graduationcap") {
                                editor = GradeEditorTarget(level: level, kind: .periodFinal, period: period)
                            }
                        } label: { Image(systemName: "plus") }
                            .disabled(subjects.isEmpty)
                    } else {
                        Menu {
                            Button("Adicionar nota de período", systemImage: "graduationcap") {
                                editor = GradeEditorTarget(level: level, kind: .periodFinal, period: period, year: year)
                            }
                            Button("Adicionar nota de teste", systemImage: "doc.text") {
                                editor = GradeEditorTarget(level: level, year: year)
                            }
                        } label: { Image(systemName: "plus") }
                            .disabled(subjects.isEmpty)
                    }
                }
            }
            .sheet(item: $editor) { target in
                NavigationStack { GradeFormView(target: target) }
                    .formSheet()
            }
            .sheet(isPresented: $showSubjects) { SubjectsView().formSheet() }
        }
    }

    // MARK: Chips

    private var levelChips: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(EducationLevel.allCases) { option in
                    let selected = option == level
                    Button {
                        withAnimation(.snappy) { level = option }
                    } label: {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(selected ? .white : .primary)
                            .glassEffect(selected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                                         in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var tabChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip("Notas de período", .terms)
                    chip("Testes", .subjects)
                    chip("Histórico", .history)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ title: String, _ value: GradesTab) -> some View {
        let selected = effectiveTab == value
        return Button {
            withAnimation(.snappy) { tab = value }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? .white : .primary)
                .glassEffect(selected ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: Hero

    private var hero: some View {
        let range = level.scale
        let fraction = overall.map { ($0 - range.lowerBound) / (range.upperBound - range.lowerBound) } ?? 0
        let tint = overall.map { color(passing: GradeCalculator.isPassing($0, level: level)) } ?? Color.secondary

        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.1), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: max(0.001, min(1, fraction)))
                        .stroke(tint.gradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .opacity(overall == nil ? 0 : 1)
                        .animation(.snappy, value: fraction)
                    VStack(spacing: 0) {
                        Text(overall.map(level.format) ?? "—")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                        Text("/ \(level.format(range.upperBound))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 116, height: 116)

                VStack(alignment: .leading, spacing: 6) {
                    Text("MÉDIA GERAL")
                        .font(.caption.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                    if let overall {
                        Text(statusText(for: overall))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(tint.opacity(0.18), in: Capsule())
                            .foregroundStyle(tint)
                        Text(level == .basic
                             ? "Média das tuas notas de período, \(period).º período"
                             : "Média dos 3 anos · final \(Int(overall.rounded()))")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Adiciona uma nota de período para veres a tua média")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(level.scaleDescription)
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }

            if level == .secondary {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach([10, 11, 12], id: \.self) { number in
                            let selected = number == year
                            let average = GradeCalculator.overallAverage(subjects: subjects, level: .secondary, year: number)
                            Button {
                                withAnimation(.snappy) { year = number; selectedPeriod = nil }
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(number).º ano").font(.subheadline.weight(.semibold))
                                    Text(average.map(level.format) ?? "—").font(.caption.monospacedDigit())
                                        .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(selected ? .white : .primary)
                                .glassEffect(selected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                                             in: .rect(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(1...3, id: \.self) { number in
                        let selected = number == period
                        Button {
                            withAnimation(.snappy) { selectedPeriod = number }
                        } label: {
                            Text("\(number).º período")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(selected ? .white : .primary)
                                .glassEffect(selected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                                             in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    // MARK: Term marks

    private var termSection: some View {
        Section {
            if visibleSubjects.isEmpty {
                Text("Sem disciplinas no \(year).º ano. Adiciona disciplinas no separador Estudo (ícone dos livros) e assinala este ano.")
                    .foregroundStyle(.secondary)
                    .cardRow()
            }
            ForEach(visibleSubjects) { subject in
                let mark = GradeCalculator.termMark(for: subject, period: period, level: level, year: activeYear)
                Button {
                    if let mark {
                        editor = GradeEditorTarget(grade: mark, level: level)
                    } else {
                        editor = GradeEditorTarget(subject: subject, level: level, kind: .periodFinal,
                                                   period: period, year: activeYear)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle().fill(subject.color).frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(subject.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                            if level == .secondary {
                                Text(durationLabel(subject)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let mark {
                            badge(level.format(mark.score), color: color(passing: GradeCalculator.isPassing(mark)))
                        } else {
                            Label("Adicionar", systemImage: "plus")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                        }
                    }
                    .padding(14)
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))
                }
                .buttonStyle(.plain)
                .cardRow()
                .swipeActions {
                    if let mark {
                        Button(role: .destructive) { delete(mark) } label: { Label("Eliminar", systemImage: "trash") }
                    }
                }
            }
        } header: {
            sectionHeader(level == .secondary ? "\(year).º ano · \(period).º período" : "Notas de período · \(period).º período",
                          detail: nil)
        } footer: {
            Text(level == .secondary
                 ? "A tua nota de 0–20 a cada disciplina. O último período de cada ano é a nota desse ano; a nota final da disciplina é a média dos seus anos."
                 : "A tua nota de 1–5 a cada disciplina no fim do período. Estas notas contam para a média geral.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func durationLabel(_ subject: Subject) -> String {
        switch subject.secondaryYears.count {
        case 3: "Trienal · conta ×3"
        case 2: "Bienal · conta ×2"
        default: "Anual · conta ×1"
        }
    }

    // MARK: History

    private var historySection: some View {
        let all = subjects.flatMap(\.grades)
            .filter { $0.educationLevel == level && $0.kind == .test }
            .sorted { $0.date > $1.date }
        return Section {
            if all.isEmpty {
                Text("Ainda não há notas guardadas. Toca em + para adicionar a primeira.")
                    .foregroundStyle(.secondary)
                    .cardRow()
            }
            ForEach(all) { grade in
                markCard(grade, showSubject: true)
            }
        } header: {
            sectionHeader("Todos os testes guardados", detail: "\(all.count)")
        }
    }

    // MARK: Subjects

    @ViewBuilder
    private func subjectSection(_ subject: Subject) -> some View {
        let tests = GradeCalculator.tests(of: subject, level: level, year: year).sorted { $0.date > $1.date }
        let testAverage = GradeCalculator.testAverage(for: subject, level: level, year: year)
        let totalWeight = tests.reduce(0) { $0 + $1.weight }

        Section {
            ForEach(tests) { grade in
                markCard(grade, showSubject: false)
            }

            Button {
                editor = GradeEditorTarget(subject: subject, level: level, year: activeYear)
            } label: {
                Label("Adicionar nota", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .cardRow()
        } header: {
            HStack(spacing: 8) {
                Circle().fill(subject.color).frame(width: 12, height: 12)
                Text(subject.name).font(.headline)
                Spacer()
                if let testAverage {
                    Text("média " + level.formatTest(testAverage))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(level == .basic ? testColor(testAverage)
                                         : color(passing: GradeCalculator.isPassing(testAverage, level: level)))
                }
            }
            .textCase(nil)
        } footer: {
            if level == .secondary && !tests.isEmpty && abs(totalWeight - 100) > 0.01 {
                Text("Os pesos somam \(totalWeight.pt)%. A média é normalizada de acordo com os pesos introduzidos.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func markCard(_ grade: Grade, showSubject: Bool) -> some View {
        let tint = color(for: grade)
        return Button { editor = GradeEditorTarget(grade: grade, level: level) } label: {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    if showSubject {
                        Circle().fill(grade.subject?.color ?? .gray).frame(width: 12, height: 12)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(rowTitle(grade)).font(.body.weight(.semibold)).foregroundStyle(.primary)
                        Text(rowSubtitle(grade)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    badge(scoreText(grade), color: tint)
                }
                if grade.educationLevel == .basic && grade.kind == .test {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule().fill(tint.gradient)
                                .frame(width: geo.size.width * min(1, max(0, grade.score / 100)))
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .cardRow()
        .swipeActions {
            Button(role: .destructive) { delete(grade) } label: { Label("Eliminar", systemImage: "trash") }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.headline.monospacedDigit())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private func sectionHeader(_ title: String, detail: String?) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.headline)
            if let detail {
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
    }

    private func delete(_ grade: Grade) {
        withAnimation { modelContext.delete(grade) }
        try? modelContext.save()
    }

    // MARK: Helpers

    private func rowTitle(_ grade: Grade) -> String {
        if grade.kind == .periodFinal {
            return "\(grade.subject?.name ?? "") · " + (grade.year > 0 ? "\(grade.year).º ano, " : "") + "\(grade.period).º período"
        }
        if !grade.title.isEmpty { return grade.title }
        return "Teste " + (grade.subject?.name ?? "")
    }

    private func rowSubtitle(_ grade: Grade) -> String {
        let date = grade.date.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(.pt))
        if level == .secondary && grade.kind == .test { return "\(grade.year).º ano · peso \(grade.weight.pt)% · \(date)" }
        return date
    }

    private func scoreText(_ grade: Grade) -> String {
        grade.kind == .periodFinal ? level.format(grade.score) : level.formatTest(grade.score)
    }

    private func color(passing: Bool) -> Color { passing ? .green : .red }

    /// Básico test percentages: below 50% red, 50–65% yellow, 65% and above green.
    private func color(for grade: Grade) -> Color {
        guard grade.educationLevel == .basic && grade.kind == .test else {
            return color(passing: GradeCalculator.isPassing(grade))
        }
        return testColor(grade.score)
    }

    private func testColor(_ percent: Double) -> Color {
        switch percent {
        case ..<50: return .red
        case ..<65: return .yellow
        default: return .green
        }
    }

    private func statusText(for value: Double) -> String {
        switch level {
        case .basic:
            let nivel = Int(value.rounded())
            return GradeCalculator.isPassing(value, level: level) ? "Positiva · Nível \(nivel)" : "Negativa · Nível \(nivel)"
        case .secondary:
            return GradeCalculator.isPassing(value, level: level) ? "Positiva (≥ 10)" : "Negativa (< 10)"
        }
    }
}

enum GradesTab: Hashable { case terms, subjects, history }

private extension View {
    /// Transparent, separator-free list row so the content can be its own glass card.
    func cardRow(top: CGFloat = 5, bottom: CGFloat = 5, horizontal: CGFloat = 16) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: horizontal, bottom: bottom, trailing: horizontal))
    }
}

struct GradeEditorTarget: Identifiable {
    let id = UUID()
    var grade: Grade?
    var subject: Subject?
    var level: EducationLevel
    var kind: GradeKind
    var period: Int
    var year: Int

    init(grade: Grade? = nil, subject: Subject? = nil, level: EducationLevel,
         kind: GradeKind = .test, period: Int = 1, year: Int = 0) {
        self.grade = grade
        self.subject = subject
        self.level = level
        self.kind = grade?.kind ?? kind
        self.period = grade?.period ?? period
        self.year = grade?.year ?? year
    }
}

struct GradeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]

    let target: GradeEditorTarget

    private let kind: GradeKind

    @State private var subject: Subject?
    @State private var title: String
    @State private var scoreText: String
    @State private var weightText: String
    @State private var date: Date
    @State private var period: Int
    @State private var year: Int
    @State private var notaValue: Int

    init(target: GradeEditorTarget) {
        self.target = target
        self.kind = target.kind
        let grade = target.grade
        let level = grade?.educationLevel ?? target.level
        _subject = State(initialValue: grade?.subject ?? target.subject)
        _title = State(initialValue: grade?.title ?? "")
        _scoreText = State(initialValue: grade.map { $0.score.formatted(.number.precision(.fractionLength(0...2)).locale(.pt)) } ?? "")
        _weightText = State(initialValue: grade.map { $0.weight.pt } ?? "")
        _date = State(initialValue: grade?.date ?? .now)
        _period = State(initialValue: target.period)
        _year = State(initialValue: target.year == 0 ? 10 : target.year)
        let fallback = level == .basic ? 3 : 10
        let range = level.scale
        _notaValue = State(initialValue: min(Int(range.upperBound), max(Int(range.lowerBound), Int((grade?.score ?? Double(fallback)).rounded()))))
    }

    private var level: EducationLevel { target.grade?.educationLevel ?? target.level }
    private var isPeriodFinal: Bool { kind == .periodFinal }

    /// Subjects offered in the picker (Secundário: only those taught in the chosen year).
    private var availableSubjects: [Subject] {
        level == .basic ? subjects : subjects.filter { $0.secondaryYears.contains(year) || $0 == subject }
    }

    private var score: Double? { isPeriodFinal ? Double(notaValue) : GradeCalculator.parse(scoreText) }
    /// Básico marks all count equally; Secundário tests use the weight entered.
    private var weight: Double? { level == .basic || isPeriodFinal ? 1 : GradeCalculator.parse(weightText) }

    private var scoreError: String? {
        guard !isPeriodFinal, !scoreText.isEmpty else { return nil }
        guard let score else { return "Introduz um número." }
        let range = level.testScale
        return range.contains(score) ? nil : "Tem de estar entre \(range.lowerBound.pt) e \(range.upperBound.pt)."
    }

    private var isValid: Bool {
        guard subject != nil, let score, let weight else { return false }
        return (isPeriodFinal ? level.scale : level.testScale).contains(score) && weight > 0
    }

    var body: some View {
        Form {
            Section {
                if level == .secondary {
                    Picker("Ano", selection: $year) {
                        ForEach([10, 11, 12], id: \.self) { Text("\($0).º").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                SubjectPickerField(selection: $subject, subjects: availableSubjects)
                if !isPeriodFinal {
                    TextField(level == .basic ? "Nome (opcional – por omissão “Teste \(subject?.name ?? "disciplina")”)" : "Título (ex.: Teste 1)",
                              text: $title)
                }
                DatePicker("Data", selection: $date, displayedComponents: .date)
            }

            if isPeriodFinal {
                Section {
                    Picker("Período", selection: $period) {
                        ForEach(1...3, id: \.self) { Text("\($0).º").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if level == .basic {
                        Picker("Nota", selection: $notaValue) {
                            ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Stepper("Nota: \(notaValue)", value: $notaValue, in: 0...20)
                    }
                } header: {
                    Text(level == .basic ? "Nota de período (1–5)" : "Nota de período (0–20)")
                } footer: {
                    Text(level == .basic
                         ? "A tua nota a esta disciplina no fim do período. Conta para a média geral."
                         : "A tua nota a esta disciplina neste período. A nota do ano é a do último período, e todos os anos contam para a média final.")
                }
            } else {
                Section {
                    HStack {
                        Text(level == .basic ? "Nota do teste (%)" : "Classificação")
                        TextField(level == .basic ? "0 – 100" : "0 – 20", text: $scoreText)
                            .decimalKeyboard()
                            .multilineTextAlignment(.trailing)
                    }
                    if level == .secondary {
                        HStack {
                            Text("Peso (%)")
                            TextField("e.g. 30", text: $weightText)
                                .decimalKeyboard()
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    Text(level.title)
                } footer: {
                    if let scoreError {
                        Text(scoreError).foregroundStyle(.red)
                    } else if level == .basic {
                        Text("Guardada para a poderes consultar no histórico de testes.")
                    } else {
                        Text("As notas de teste ficam guardadas para consulta; o que conta para a média são as notas de período.")
                    }
                }
            }

            if let grade = target.grade {
                Section {
                    Button("Eliminar", role: .destructive) {
                        modelContext.delete(grade)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(isPeriodFinal ? "Nota de período" : (target.grade == nil ? "Novo teste" : "Editar teste"))
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).disabled(!isValid) }
        }
    }

    private func save() {
        guard let score, let weight else { return }
        let trimmed = isPeriodFinal ? "" : title.trimmingCharacters(in: .whitespaces)
        let savedYear = level == .secondary ? year : 0
        // One term mark per subject, year and period: saving again updates it.
        let existingTerm = (target.grade == nil && isPeriodFinal)
            ? subject.flatMap { GradeCalculator.termMark(for: $0, period: period, level: level, year: savedYear) } : nil
        if let grade = target.grade ?? existingTerm {
            grade.subject = subject
            grade.title = trimmed
            grade.score = score
            grade.weight = weight
            grade.date = date
            grade.kind = kind
            grade.period = period
            grade.year = savedYear
        } else {
            modelContext.insert(Grade(subject: subject, title: trimmed, score: score, weight: weight,
                                      educationLevel: level, date: date, kind: kind, period: period, year: savedYear))
        }
        try? modelContext.save()
        dismiss()
    }
}
