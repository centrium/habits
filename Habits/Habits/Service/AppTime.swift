import Foundation
import Combine

@MainActor
final class AppTime: ObservableObject {
    static let shared = AppTime()

    @Published private(set) var now: Date = Date()

    private var timer: Timer?
    private let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        scheduleNextTick()
    }

    deinit {
        timer?.invalidate()
    }

    func refreshIfNeeded() {
        let current = Date()
        if abs(current.timeIntervalSince(now)) > 1 {
            now = current
            scheduleNextTick()
        }
    }

    private func scheduleNextTick() {
        let current = Date()

        let next = calendar.nextDate(
            after: current,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime
        ) ?? current.addingTimeInterval(60)

        let interval = max(next.timeIntervalSince(current), 0.1)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.now = Date()
                self.scheduleNextTick()
            }
        }
    }
}
