import Foundation

final class DateFormatters: @unchecked Sendable {
    static let shared = DateFormatters()
    private init() {}
    
    let apiDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    let apiDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    let display: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    let displayShort: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()
    
    func daysLabel(for dateString: String?) -> String? {
        guard let s = dateString, s != "2999-12-31" else { return nil }
        guard let date = apiDate.date(from: s) else { return display.string(from: Date()) }
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        if days < 0 { return "Expired \(abs(days))d ago" }
        if days == 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }
}
