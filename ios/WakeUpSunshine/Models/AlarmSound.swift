import SwiftUI
import AVFoundation

// MARK: - Alarm Sound Model
/// 4 custom sounds + classic (system fallback). IDs must match Android and backend.
enum AlarmSound: String, CaseIterable, Identifiable, Codable {
    case wakeUp      = "wake_up"
    case heyYou      = "hey_you"
    case minions     = "minions"
    case ringingTone = "ringing_tone"
    case classic     = "classic"   // plays system alarm — no file needed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wakeUp:      return "Wake Up"
        case .heyYou:      return "Hey You Wake"
        case .minions:     return "Minions"
        case .ringingTone: return "Ringing Tone"
        case .classic:     return "Classic Alarm"
        }
    }

    var description: String {
        switch self {
        case .wakeUp:      return "Rise and shine!"
        case .heyYou:      return "Hey, get up!"
        case .minions:     return "Banana time!"
        case .ringingTone: return "Classic phone ring"
        case .classic:     return "Traditional alarm"
        }
    }

    var iconName: String {
        switch self {
        case .wakeUp:      return "sun.max.fill"
        case .heyYou:      return "hand.wave.fill"
        case .minions:     return "face.smiling.fill"
        case .ringingTone: return "phone.fill"
        case .classic:     return "alarm"
        }
    }

    var iconColor: Color {
        switch self {
        case .wakeUp:      return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .heyYou:      return Color(red: 0.3, green: 0.7, blue: 0.4)
        case .minions:     return Color(red: 0.95, green: 0.8, blue: 0.1)
        case .ringingTone: return Color(red: 0.2, green: 0.5, blue: 0.9)
        case .classic:     return Color(red: 0.9, green: 0.3, blue: 0.3)
        }
    }

    static var `default`: AlarmSound { .classic }
    static var allSounds: [AlarmSound] { allCases }
    static var allowedIds: Set<String> { Set(allCases.map { $0.id }) }

    static func from(id: String?) -> AlarmSound {
        guard let id else { return .default }
        return AlarmSound(rawValue: id) ?? .default
    }
}

// MARK: - WakeRequest Extension
extension WakeRequest {
    var alarmSound: AlarmSound { AlarmSound.from(id: alarmSoundId) }
}
