#if DEBUG
import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

/// Development helpers: demo data and window snapshots (no screen-recording permission needed).
enum DebugTools {
    static var env: [String: String] { ProcessInfo.processInfo.environment }

    @MainActor
    static func seedDemoDataIfRequested(_ context: ModelContext) {
        guard env["STUDYLAB_DEMO"] == "1" else { return }
        guard (try? context.fetchCount(FetchDescriptor<Subject>())) == 0 else { return }

        let mat = Subject(name: "Matemática", colorHex: "#4F6DF2", targetHours: 4)
        let por = Subject(name: "Português", colorHex: "#EF4444", targetHours: 3)
        let fis = Subject(name: "Física e Química", colorHex: "#22C55E", targetHours: 3)
        let ing = Subject(name: "Inglês", colorHex: "#F97316", targetHours: 2)
        [mat, por, fis, ing].forEach(context.insert)

        let cal = Calendar.current
        func day(_ offset: Int, hour: Int = 9) -> Date {
            cal.date(bySettingHour: hour, minute: 0, second: 0, of: cal.date(byAdding: .day, value: offset, to: .now)!)!
        }
        context.insert(StudyTask(title: "Ficha de exercícios 5", subject: mat, type: .homework, dueDate: day(0, hour: 18)))
        context.insert(StudyTask(title: "Teste de funções", subject: mat, type: .test, dueDate: day(3)))
        context.insert(StudyTask(title: "Comentário a Os Maias", subject: por, type: .assignment, dueDate: day(5)))
        context.insert(StudyTask(title: "Relatório de laboratório", subject: fis, type: .assignment, dueDate: day(-1)))
        context.insert(StudyTask(title: "Vocabulário unit 4", subject: ing, type: .homework, dueDate: day(1), isCompleted: true))

        let classes: [(Subject, Weekday, Int, Int, String)] = [
            (mat, .monday, 8*60+30, 10*60, "B12"), (por, .monday, 10*60+15, 11*60+45, "A03"),
            (fis, .tuesday, 9*60, 10*60+30, "Lab 2"), (ing, .tuesday, 11*60, 12*60+30, "A07"),
            (mat, .wednesday, 8*60+30, 10*60, "B12"), (por, .thursday, 9*60, 10*60+30, "A03"),
            (fis, .thursday, 14*60, 15*60+30, "Lab 2"), (mat, .friday, 10*60, 11*60+30, "B12"),
            (ing, .friday, 13*60, 14*60+30, "A07")
        ]
        for c in classes { context.insert(TimetableEntry(subject: c.0, dayOfWeek: c.1, startTime: c.2, endTime: c.3, room: c.4)) }

        for i in 0..<14 {
            let subject = [mat, por, fis, ing][i % 4]
            context.insert(StudySession(subject: subject, durationInSeconds: 1500 + (i % 3) * 900,
                                        dateCompleted: day(-(i % 9), hour: 17)))
        }

        for (s, y, p, v) in [(mat, 10, 1, 15.0), (mat, 10, 2, 16.0), (por, 10, 1, 13.0), (por, 10, 2, 14.0),
                             (fis, 10, 1, 12.0), (ing, 10, 1, 17.0)] {
            context.insert(Grade(subject: s, score: v, weight: 1, educationLevel: .secondary,
                                 kind: .periodFinal, period: p, year: y))
        }
        try? context.save()
    }

    #if os(macOS)
    /// Saves the key window's content to a PNG, then quits. Used to review the Mac UI from the command line.
    @MainActor
    static func scheduleSnapshotIfRequested() {
        guard let path = env["STUDYLAB_SNAPSHOT"] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            guard let window = NSApp.windows.first(where: { $0.isVisible }) else { exit(2) }
            // Compositor-level capture of this app's own window (includes glass / Metal layers).
            typealias CaptureFn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
            if let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") {
                let capture = unsafeBitCast(sym, to: CaptureFn.self)
                // optionIncludingWindow = 1 << 3, boundsIgnoreFraming = 1 << 0
                if let image = capture(.null, 1 << 3, UInt32(window.windowNumber), 1 << 0)?.takeRetainedValue() {
                    let rep = NSBitmapImageRep(cgImage: image)
                    if let data = rep.representation(using: .png, properties: [:]) {
                        try? data.write(to: URL(fileURLWithPath: path))
                        exit(0)
                    }
                }
            }
            guard let view = window.contentView?.superview,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(2) }
            view.cacheDisplay(in: view.bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: path))
            }
            exit(0)
        }
    }
    #endif
}
#endif
