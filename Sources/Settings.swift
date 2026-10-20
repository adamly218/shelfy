import AppKit
import ServiceManagement

/// User preferences, stored in UserDefaults. Posts `Settings.didChange` when any value changes.
enum Settings {
    static let didChange = Notification.Name("ShelfySettingsDidChange")

    /// Which key must be held while shaking, if any.
    enum Modifier: Int, CaseIterable {
        case none, option, control, command, shift

        var title: String {
            switch self {
            case .none: return "None"
            case .option: return "⌥ Option"
            case .control: return "⌃ Control"
            case .command: return "⌘ Command"
            case .shift: return "⇧ Shift"
            }
        }

        var flag: NSEvent.ModifierFlags? {
            switch self {
            case .none: return nil
            case .option: return .option
            case .control: return .control
            case .command: return .command
            case .shift: return .shift
            }
        }
    }

    /// Where a new shelf appears.
    enum Placement: Int, CaseIterable {
        case besideCursor, underCursor, screenCenter

        var title: String {
            switch self {
            case .besideCursor: return "Beside the cursor"
            case .underCursor: return "Under the cursor"
            case .screenCenter: return "Center of the screen"
            }
        }
    }

    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        // Carry over the old Normal / High / Very High menu choice.
        let oldLevels: [Double] = [0.4, 0.65, 0.9]
        let old = defaults.object(forKey: "ShakeSensitivity") as? Int
        defaults.register(defaults: [
            "ShakeEnabled": true,
            "ShakeSensitivityLevel": old.map { oldLevels[min(max($0, 0), 2)] } ?? 0.4,
            "ShakeModifier": Modifier.none.rawValue,
            "ShelfPlacement": Placement.besideCursor.rawValue,
            "ShelfAlwaysOnTop": true,
            "ShelfAllDesktops": true,
            "ShelfCloseWhenEmpty": true,
            "ShelfPlaySound": false,
        ])
    }

    static var shakeEnabled: Bool {
        get { defaults.bool(forKey: "ShakeEnabled") }
        set { set(newValue, "ShakeEnabled") }
    }

    /// 0 = needs a big, fast shake; 1 = a small wiggle is enough.
    static var sensitivity: Double {
        get { defaults.double(forKey: "ShakeSensitivityLevel") }
        set { set(min(max(newValue, 0), 1), "ShakeSensitivityLevel") }
    }

    static var modifier: Modifier {
        get { Modifier(rawValue: defaults.integer(forKey: "ShakeModifier")) ?? .none }
        set { set(newValue.rawValue, "ShakeModifier") }
    }

    static var placement: Placement {
        get { Placement(rawValue: defaults.integer(forKey: "ShelfPlacement")) ?? .besideCursor }
        set { set(newValue.rawValue, "ShelfPlacement") }
    }

    static var alwaysOnTop: Bool {
        get { defaults.bool(forKey: "ShelfAlwaysOnTop") }
        set { set(newValue, "ShelfAlwaysOnTop") }
    }

    static var allDesktops: Bool {
        get { defaults.bool(forKey: "ShelfAllDesktops") }
        set { set(newValue, "ShelfAllDesktops") }
    }

    static var closeWhenEmpty: Bool {
        get { defaults.bool(forKey: "ShelfCloseWhenEmpty") }
        set { set(newValue, "ShelfCloseWhenEmpty") }
    }

    static var playSound: Bool {
        get { defaults.bool(forKey: "ShelfPlaySound") }
        set { set(newValue, "ShelfPlaySound") }
    }

    /// Stored by macOS itself, not in UserDefaults.
    static var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Shelfy: couldn't change login item: \(error)")
            }
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    private static func set(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
