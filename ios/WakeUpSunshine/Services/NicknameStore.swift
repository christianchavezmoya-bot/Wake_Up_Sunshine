import Foundation

enum NicknameStore {
    private static let prefix = "nickname_"

    static func get(for email: String) -> String? {
        UserDefaults.standard.string(forKey: prefix + email)?.nonEmpty
    }

    static func set(_ nickname: String?, for email: String) {
        let trimmed = nickname?.trimmingCharacters(in: .whitespaces)
        if let trimmed, !trimmed.isEmpty {
            UserDefaults.standard.set(trimmed, forKey: prefix + email)
        } else {
            UserDefaults.standard.removeObject(forKey: prefix + email)
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
