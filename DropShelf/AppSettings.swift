import Foundation
import Combine

enum ShakeSensitivity: String, CaseIterable, Identifiable {
    case low, normal, high
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// How many quick left/right direction changes count as a shake.
    var requiredReversals: Int {
        switch self {
        case .low: 5
        case .normal: 4
        case .high: 3
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var shakeEnabled: Bool {
        didSet { defaults.set(shakeEnabled, forKey: "shakeEnabled") }
    }
    @Published var sensitivity: ShakeSensitivity {
        didSet { defaults.set(sensitivity.rawValue, forKey: "sensitivity") }
    }
    /// Remove items from a shelf once they've been dragged out somewhere.
    @Published var removeAfterDragOut: Bool {
        didSet { defaults.set(removeAfterDragOut, forKey: "removeAfterDragOut") }
    }

    private init() {
        defaults.register(defaults: [
            "shakeEnabled": true,
            "sensitivity": ShakeSensitivity.normal.rawValue,
            "removeAfterDragOut": true,
        ])
        shakeEnabled = defaults.bool(forKey: "shakeEnabled")
        sensitivity = ShakeSensitivity(rawValue: defaults.string(forKey: "sensitivity") ?? "") ?? .normal
        removeAfterDragOut = defaults.bool(forKey: "removeAfterDragOut")
    }
}
