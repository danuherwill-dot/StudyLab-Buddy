import SwiftUI
import SwiftData

@Model
final class Subject {
    var name: String
    var colorHex: String
    /// Weekly study goal in hours.
    var targetHours: Double
    /// Secundário years (10, 11, 12) in which the subject is taught. The count (3/2/1) is the subject's weight in the final average.
    var secondaryYears: [Int] = [10, 11, 12]

    @Relationship(deleteRule: .cascade, inverse: \StudyTask.subject) var tasks: [StudyTask] = []
    @Relationship(deleteRule: .cascade, inverse: \TimetableEntry.subject) var timetableEntries: [TimetableEntry] = []
    @Relationship(deleteRule: .cascade, inverse: \StudySession.subject) var sessions: [StudySession] = []
    @Relationship(deleteRule: .cascade, inverse: \Grade.subject) var grades: [Grade] = []

    init(name: String, colorHex: String, targetHours: Double = 3) {
        self.name = name
        self.colorHex = colorHex
        self.targetHours = targetHours
    }

    var color: Color { Color(hex: colorHex) }
}
