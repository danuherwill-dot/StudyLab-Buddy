import Foundation

enum TaskType: String, Codable, CaseIterable, Identifiable {
    case homework, test, assignment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .homework: "TPC"
        case .test: "Teste"
        case .assignment: "Trabalho"
        }
    }

    var pluralTitle: String {
        switch self {
        case .homework: "TPC"
        case .test: "Testes"
        case .assignment: "Trabalhos"
        }
    }

    var systemImage: String {
        switch self {
        case .homework: "text.book.closed"
        case .test: "pencil.and.list.clipboard"
        case .assignment: "doc.text"
        }
    }
}

enum GradeKind: String, Codable {
    case test        // a single test/assessment mark
    case periodFinal // Ensino Básico: the subject's final 1–5 nota for a period
}

enum EducationLevel: String, Codable, CaseIterable, Identifiable {
    case basic      // Ensino Básico: 1–5
    case secondary  // Ensino Secundário / Superior: 0–20

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: "Ensino Básico"
        case .secondary: "Secundário / Superior"
        }
    }

    var scale: ClosedRange<Double> {
        switch self {
        case .basic: 1...5
        case .secondary: 0...20
        }
    }

    var passingGrade: Double {
        switch self {
        case .basic: 3
        case .secondary: 10
        }
    }

    var fractionDigits: Int {
        switch self {
        case .basic: 1
        case .secondary: 2
        }
    }

    var scaleDescription: String {
        switch self {
        case .basic: "Testes 0–100% · nota de período 1–5 · positiva ≥ 3"
        case .secondary: "Escala 0–20 · positiva ≥ 10"
        }
    }

    /// Range for a single test mark: 0–100% in Básico, 0–20 in Secundário/Superior.
    var testScale: ClosedRange<Double> {
        switch self {
        case .basic: 0...100
        case .secondary: 0...20
        }
    }

    func formatTest(_ value: Double) -> String {
        switch self {
        case .basic: value.formatted(.number.precision(.fractionLength(0...1)).locale(.pt)) + "%"
        case .secondary: format(value)
        }
    }

    func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)).locale(.pt))
    }
}

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    var shortName: String {
        ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"][rawValue - 1]
    }

    var fullName: String {
        ["Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado", "Domingo"][rawValue - 1]
    }

    static var schoolDays: [Weekday] { [.monday, .tuesday, .wednesday, .thursday, .friday] }

    static var today: Weekday {
        let w = Calendar.current.component(.weekday, from: .now) // 1 = Sunday
        return Weekday(rawValue: w == 1 ? 7 : w - 1) ?? .monday
    }
}
