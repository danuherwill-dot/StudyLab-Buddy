import Foundation
import SwiftData

@Model
final class Grade {
    var subject: Subject?
    var title: String
    var score: Double
    /// Relative weight (e.g. a percentage). Averages are normalised by the sum of weights.
    var weight: Double
    var educationLevel: EducationLevel
    var date: Date
    var kind: GradeKind = GradeKind.test
    /// 1–3, only used for `.periodFinal`.
    var period: Int = 1
    /// Secundário school year (10, 11 or 12); 0 for Básico.
    var year: Int = 0

    init(subject: Subject?, title: String = "", score: Double, weight: Double,
         educationLevel: EducationLevel, date: Date = .now,
         kind: GradeKind = .test, period: Int = 1, year: Int = 0) {
        self.subject = subject
        self.title = title
        self.score = score
        self.weight = weight
        self.educationLevel = educationLevel
        self.date = date
        self.kind = kind
        self.period = period
        self.year = year
    }
}
