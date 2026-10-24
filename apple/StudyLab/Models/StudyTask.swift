import Foundation
import SwiftData

/// Named `StudyTask` (not `Task`) so it doesn't shadow Swift Concurrency's `Task`.
@Model
final class StudyTask {
    var id: UUID
    var title: String
    var subject: Subject?
    var type: TaskType
    var dueDate: Date
    var isCompleted: Bool
    var remindMe: Bool

    init(title: String,
         subject: Subject? = nil,
         type: TaskType = .homework,
         dueDate: Date,
         isCompleted: Bool = false,
         remindMe: Bool = true) {
        self.id = UUID()
        self.title = title
        self.subject = subject
        self.type = type
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.remindMe = remindMe
    }

    var isOverdue: Bool { !isCompleted && dueDate < .now }
}
