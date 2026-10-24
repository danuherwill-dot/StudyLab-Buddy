import Foundation
import SwiftData

@Model
final class TimetableEntry {
    var subject: Subject?
    var dayOfWeek: Weekday
    /// Minutes since midnight (e.g. 08:30 → 510).
    var startTime: Int
    /// Minutes since midnight.
    var endTime: Int
    var room: String

    init(subject: Subject?, dayOfWeek: Weekday, startTime: Int, endTime: Int, room: String = "") {
        self.subject = subject
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.room = room
    }

    var timeRangeText: String {
        "\(Self.text(minutes: startTime))–\(Self.text(minutes: endTime))"
    }

    static func text(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
