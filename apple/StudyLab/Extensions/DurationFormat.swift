import Foundation

enum DurationFormat {
    /// "25:00" or "1:05:09"
    static func clock(seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// "1h 25m", "25m", "40s"
    static func short(seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60
        if h > 0 { return "\(h) h \(m) min" }
        if m > 0 { return "\(m) min" }
        return "\(seconds)s"
    }

    static func hours(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(.pt)) + " h"
    }
}
