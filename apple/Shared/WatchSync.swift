import Foundation

// Data shared between the iPhone app and the Apple Watch app (sent with WatchConnectivity).

struct WatchSubject: Codable, Identifiable, Hashable {
    let id: String        // encoded SwiftData identifier on the iPhone
    let name: String
    let colorHex: String
}

struct WatchClass: Codable, Identifiable, Hashable {
    let id: String
    let subjectName: String
    let colorHex: String
    let weekday: Int      // 1 = Monday … 7 = Sunday
    let start: Int        // minutes since midnight
    let end: Int
    let room: String
}

struct WatchTask: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subjectName: String
    let colorHex: String
    let typeTitle: String
    let typeIcon: String
    let due: Date
    var isCompleted: Bool
}

struct WatchSnapshot: Codable {
    var subjects: [WatchSubject]
    var classes: [WatchClass]
    var tasks: [WatchTask]
    var generated: Date
}

/// A finished study session logged on the watch, sent back to the iPhone.
struct WatchSessionLog: Codable {
    let subjectID: String
    let seconds: Int
    let date: Date
    let notes: String
}

enum WatchKey {
    static let snapshot = "snapshot"
    static let session = "session"
    static let toggleTask = "toggleTask"
    static let requestSnapshot = "requestSnapshot"
}
