import SwiftUI
import SwiftData

struct SubjectsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var timer
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State private var editing: Subject?
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(subjects) { subject in
                    Button {
                        editing = subject
                    } label: {
                        HStack(spacing: 12) {
                            Circle().fill(subject.color).frame(width: 14, height: 14)
                            Text(subject.name).foregroundStyle(.primary)
                            Spacer()
                            Text("\(subject.targetHours.pt) h/semana")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if subjects.isEmpty {
                    ContentUnavailableView("Ainda sem disciplinas", systemImage: "books.vertical",
                                           description: Text("Adiciona as tuas disciplinas para associar sessões de estudo, tarefas e notas."))
                }
            }
            .navigationTitle("Disciplinas")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .leadingBar) { Button("Concluído") { dismiss() } }
                ToolbarItem(placement: .trailingBar) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) {
                NavigationStack { SubjectFormView(subject: nil) }
                    .formSheet()
            }
            .sheet(item: $editing) { subject in
                NavigationStack { SubjectFormView(subject: subject) }
                    .formSheet()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let subject = subjects[index]
            if timer.subject?.persistentModelID == subject.persistentModelID {
                timer.discard()
                timer.subject = nil
            }
            for task in subject.tasks {
                NotificationManager.shared.cancelReminders(for: task)
            }
            modelContext.delete(subject)
        }
        try? modelContext.save()
    }
}

struct SubjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let subject: Subject?

    @State private var name: String
    @State private var colorHex: String
    @State private var targetHours: Double
    @State private var years: Set<Int>
    @AppStorage("educationLevel") private var levelRaw = EducationLevel.secondary.rawValue

    init(subject: Subject?) {
        self.subject = subject
        _name = State(initialValue: subject?.name ?? "")
        _colorHex = State(initialValue: subject?.colorHex ?? SubjectPalette.hexes[0])
        _targetHours = State(initialValue: subject?.targetHours ?? 3)
        _years = State(initialValue: Set(subject?.secondaryYears ?? [10, 11, 12]))
    }

    var body: some View {
        Form {
            Section("Nome") {
                TextField("ex.: Matemática", text: $name)
            }
            Section("Cor") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                    ForEach(SubjectPalette.hexes, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 36, height: 36)
                            .overlay {
                                if hex == colorHex {
                                    Image(systemName: "checkmark").font(.footnote.bold()).foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { colorHex = hex }
                    }
                }
                .padding(.vertical, 6)
            }
            if levelRaw == EducationLevel.secondary.rawValue {
            Section {
                HStack(spacing: 10) {
                    ForEach([10, 11, 12], id: \.self) { year in
                        let on = years.contains(year)
                        Button {
                            if on { years.remove(year) } else { years.insert(year) }
                        } label: {
                            Text("\(year).º")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(on ? Color.accentColor : Color.primary.opacity(0.08), in: Capsule())
                                .foregroundStyle(on ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Anos do Secundário")
            } footer: {
                Text("Escolhe os anos em que a disciplina é lecionada. Português, Matemática e Educação Física costumam ter 10.º, 11.º e 12.º; as disciplinas de um só ano pesam menos na média final.")
            }
            }
            Section {
                Stepper("\(targetHours.pt) horas / semana", value: $targetHours, in: 0...40, step: 0.5)
            } header: {
                Text("Meta semanal de estudo")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(subject == nil ? "Nova disciplina" : "Editar disciplina")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || years.isEmpty)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let subject {
            subject.name = trimmed
            subject.colorHex = colorHex
            subject.targetHours = targetHours
            subject.secondaryYears = years.sorted()
        } else {
            let new = Subject(name: trimmed, colorHex: colorHex, targetHours: targetHours)
            new.secondaryYears = years.sorted()
            modelContext.insert(new)
        }
        try? modelContext.save()
        dismiss()
    }
}

/// Reusable subject dropdown used by the task, timetable and grade forms.
struct SubjectPickerField: View {
    @Binding var selection: Subject?
    let subjects: [Subject]
    var allowsNone = false

    var body: some View {
        Picker("Disciplina", selection: $selection) {
            if selection == nil || allowsNone {
                Text(allowsNone ? "Nenhuma" : "Selecionar…").tag(Subject?.none)
            }
            ForEach(subjects) { subject in
                Text(subject.name).tag(Subject?.some(subject))
            }
        }
    }
}
