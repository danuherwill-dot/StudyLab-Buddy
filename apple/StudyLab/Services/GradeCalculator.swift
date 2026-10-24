import Foundation

/// Weighted-average maths for the Portuguese grading scales.
///
/// Ensino Básico: tests are 0–100%, each subject gets a 1–5 nota per period; the overall
/// average is the mean of the term marks of one period.
///
/// Ensino Secundário (0–20, pass ≥ 10): each subject has a nota per period in each year (10.º, 11.º, 12.º).
/// The nota of a year is its latest period (the 3.º período closes the year). A subject's final grade (CFD)
/// is the simple mean of its yearly grades. The course average is the mean of the CFDs, weighted by how
/// many years a subject lasts (trienal ×3, bienal ×2, anual ×1) – or a plain mean if that is switched off.
enum GradeCalculator {
    static let weightByDurationKey = "weightByDuration"

    static var weightByDuration: Bool {
        UserDefaults.standard.object(forKey: weightByDurationKey) as? Bool ?? true
    }

    /// Σ(score × weight) / Σ(weight), or nil when there is no weight.
    static func weightedAverage(_ grades: [Grade]) -> Double? {
        let totalWeight = grades.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }
        return grades.reduce(0) { $0 + $1.score * $1.weight } / totalWeight
    }

    // MARK: Tests

    static func tests(of subject: Subject, level: EducationLevel, year: Int? = nil) -> [Grade] {
        subject.grades.filter {
            $0.educationLevel == level && $0.kind == .test && (level == .basic || year == nil || $0.year == year)
        }
    }

    /// Average of test marks (0–100% in Básico, 0–20 in Secundário).
    static func testAverage(for subject: Subject, level: EducationLevel, year: Int? = nil) -> Double? {
        weightedAverage(tests(of: subject, level: level, year: year))
    }

    /// Typical Básico conversion from a test percentage to a 1–5 nível.
    static func suggestedNivel(forPercent percent: Double) -> Int {
        switch percent {
        case ..<20: 1
        case ..<50: 2
        case ..<70: 3
        case ..<90: 4
        default: 5
        }
    }

    // MARK: Term marks

    /// The subject's saved term mark for a period (Básico: year 0, Secundário: 10/11/12).
    static func termMark(for subject: Subject, period: Int, level: EducationLevel = .basic, year: Int = 0) -> Grade? {
        subject.grades
            .filter { $0.educationLevel == level && $0.kind == .periodFinal && $0.period == period && $0.year == year }
            .max { $0.date < $1.date }
    }

    /// The most recent period (1–3) that has at least one term mark.
    static func latestTermPeriod(subjects: [Subject], level: EducationLevel = .basic, year: Int = 0) -> Int? {
        subjects.flatMap(\.grades)
            .filter { $0.educationLevel == level && $0.kind == .periodFinal && $0.year == year }
            .map(\.period).max()
    }

    // MARK: Secundário

    /// A subject's grade for a school year: its latest saved period mark.
    static func yearGrade(for subject: Subject, year: Int) -> Double? {
        subject.grades
            .filter { $0.educationLevel == .secondary && $0.kind == .periodFinal && $0.year == year }
            .max { ($0.period, $0.date) < ($1.period, $1.date) }?
            .score
    }

    /// Classificação final da disciplina: mean of the yearly grades.
    static func courseGrade(for subject: Subject) -> Double? {
        let values = subject.secondaryYears.compactMap { yearGrade(for: subject, year: $0) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: Averages

    /// Básico → the subject's term mark for `period` (default: latest saved).
    /// Secundário → the grade of `year` if given, otherwise the final grade over all years.
    static func average(for subject: Subject, level: EducationLevel, period: Int? = nil, year: Int? = nil) -> Double? {
        switch level {
        case .basic:
            let p = period ?? latestTermPeriod(subjects: [subject])
            return p.flatMap { termMark(for: subject, period: $0)?.score }
        case .secondary:
            if let year { return yearGrade(for: subject, year: year) }
            return courseGrade(for: subject)
        }
    }

    /// Básico: mean of the term marks for `period`.
    /// Secundário: course average over all years (weighted by duration), or the average of one `year`.
    static func overallAverage(subjects: [Subject], level: EducationLevel, period: Int? = nil, year: Int? = nil) -> Double? {
        switch level {
        case .basic:
            let p = period ?? latestTermPeriod(subjects: subjects)
            let values = subjects.compactMap { subject in p.flatMap { termMark(for: subject, period: $0)?.score } }
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        case .secondary:
            if let year {
                let values = subjects.filter { $0.secondaryYears.contains(year) }
                    .compactMap { yearGrade(for: $0, year: year) }
                guard !values.isEmpty else { return nil }
                return values.reduce(0, +) / Double(values.count)
            }
            let weighted = weightByDuration
            var total = 0.0, weights = 0.0
            for subject in subjects {
                guard let grade = courseGrade(for: subject) else { continue }
                let w = weighted ? Double(max(1, subject.secondaryYears.count)) : 1
                total += grade * w
                weights += w
            }
            return weights > 0 ? total / weights : nil
        }
    }

    static func isPassing(_ grade: Grade) -> Bool {
        if grade.educationLevel == .basic && grade.kind == .test { return grade.score >= 50 }
        return isPassing(grade.score, level: grade.educationLevel)
    }

    static func isPassing(_ value: Double, level: EducationLevel) -> Bool {
        value >= level.passingGrade
    }

    /// Accepts both "14.5" and "14,5".
    static func parse(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}
