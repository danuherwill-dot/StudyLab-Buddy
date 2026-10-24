import Foundation

extension Locale {
    /// The app is written for European Portuguese: dates, decimal commas and weekday names follow it.
    static let pt = Locale(identifier: "pt_PT")
}

extension Double {
    /// "14,5" – locale-aware, no trailing zeros.
    var pt: String { formatted(.number.locale(.pt)) }
}
