import Foundation

public extension Date {
    func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }

    var isYesterday: Bool { Calendar.current.isDateInYesterday(self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
