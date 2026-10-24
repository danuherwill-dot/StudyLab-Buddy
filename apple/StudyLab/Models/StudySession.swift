import Foundation
import SwiftData

@Model
final class StudySession {
    var subject: Subject?
    var durationInSeconds: Int
    var dateCompleted: Date
    var notes: String

    init(subject: Subject?, durationInSeconds: Int, dateCompleted: Date = .now, notes: String = "") {
        self.subject = subject
        self.durationInSeconds = durationInSeconds
        self.dateCompleted = dateCompleted
        self.notes = notes
    }
}
