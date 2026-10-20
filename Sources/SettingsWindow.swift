import AppKit

/// The Settings window, opened from the menu bar icon. Every control saves as soon as it changes.
final class SettingsWindow: NSWindow {
    private let launchAtLogin = NSButton(checkboxWithTitle: "Open Shelfy when you log in", target: nil, action: nil)
    private let shakeEnabled = NSButton(checkboxWithTitle: "Shake while dragging files to open a shelf", target: nil, action: nil)
    private let sensitivity = NSSlider(value: 0.4, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let sensitivityValue = NSTextField(labelWithString: "")
    private let modifier = NSPopUpButton()
    private let placement = NSPopUpButton()
    private let alwaysOnTop = NSButton(checkboxWithTitle: "Keep shelves above other windows", target: nil, action: nil)
    private let allDesktops = NSButton(checkboxWithTitle: "Show shelves on every desktop", target: nil, action: nil)
    private let closeWhenEmpty = NSButton(checkboxWithTitle: "Close a shelf when its last file is dragged out", target: nil, action: nil)
    private let playSound = NSButton(checkboxWithTitle: "Play a sound when a shelf opens", target: nil, action: nil)

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 10),
                   styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "Shelfy Settings"
        isReleasedWhenClosed = false

        for button in [launchAtLogin, shakeEnabled, alwaysOnTop, allDesktops, closeWhenEmpty, playSound] {
            button.target = self
            button.action = #selector(changed(_:))
        }
        sensitivity.target = self
        sensitivity.action = #selector(changed(_:))
        sensitivity.isContinuous = true
        sensitivity.widthAnchor.constraint(equalToConstant: 220).isActive = true
        sensitivityValue.font = .systemFont(ofSize: 12, weight: .medium)
        sensitivityValue.textColor = .secondaryLabelColor
        sensitivityValue.widthAnchor.constraint(equalToConstant: 70).isActive = true

        modifier.addItems(withTitles: Settings.Modifier.allCases.map(\.title))
        placement.addItems(withTitles: Settings.Placement.allCases.map(\.title))
        for popUp in [modifier, placement] {
            popUp.target = self
            popUp.action = #selector(changed(_:))
        }

        let sliderRow = NSStackView(views: [small("Low"), sensitivity, small("High"), sensitivityValue])
        sliderRow.spacing = 6

        let grid = NSGridView(views: [
            [label("General:"), launchAtLogin],
            [spacer(), spacer()],
            [label("Shaking:"), shakeEnabled],
            [label("Sensitivity:"), sliderRow],
            [NSGridCell.emptyContentView, note("Higher means a smaller, slower shake is enough to open a shelf.")],
            [label("Hold key:"), modifier],
            [NSGridCell.emptyContentView, note("Only open a shelf when this key is held while you shake.")],
            [spacer(), spacer()],
            [label("Shelf opens:"), placement],
            [label("Shelves:"), alwaysOnTop],
            [NSGridCell.emptyContentView, allDesktops],
            [NSGridCell.emptyContentView, closeWhenEmpty],
            [NSGridCell.emptyContentView, playSound],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        // The slider row lines up better centered than on a baseline.
        grid.row(at: 3).rowAlignment = .none
        grid.row(at: 3).yPlacement = .center

        let reset = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaults))
        reset.bezelStyle = .rounded

        let stack = NSStackView(views: [grid, reset])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
        ])
        contentView = container
        setContentSize(container.fittingSize)

        reload()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: Settings.didChange, object: nil)
    }

    func present() {
        reload()
        if !isVisible { center() }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    // A menu bar app has no Window menu, so handle ⌘W and Esc here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "w" {
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) { close() }

    /// Saves a PNG of the window's contents (used for screenshots).
    func snapshot(to path: String) {
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(windowNumber), path]
        try? capture.run()
    }

    @objc private func reload() {
        launchAtLogin.state = Settings.launchAtLogin ? .on : .off
        shakeEnabled.state = Settings.shakeEnabled ? .on : .off
        sensitivity.doubleValue = Settings.sensitivity
        sensitivityValue.stringValue = Self.describe(Settings.sensitivity)
        modifier.selectItem(at: Settings.modifier.rawValue)
        placement.selectItem(at: Settings.placement.rawValue)
        alwaysOnTop.state = Settings.alwaysOnTop ? .on : .off
        allDesktops.state = Settings.allDesktops ? .on : .off
        closeWhenEmpty.state = Settings.closeWhenEmpty ? .on : .off
        playSound.state = Settings.playSound ? .on : .off

        for control in [sensitivity, modifier] as [NSControl] { control.isEnabled = Settings.shakeEnabled }
    }

    @objc private func changed(_ sender: NSControl) {
        switch sender {
        case launchAtLogin: Settings.launchAtLogin = launchAtLogin.state == .on
        case shakeEnabled: Settings.shakeEnabled = shakeEnabled.state == .on
        case sensitivity: Settings.sensitivity = sensitivity.doubleValue
        case modifier: Settings.modifier = Settings.Modifier(rawValue: modifier.indexOfSelectedItem) ?? .none
        case placement: Settings.placement = Settings.Placement(rawValue: placement.indexOfSelectedItem) ?? .besideCursor
        case alwaysOnTop: Settings.alwaysOnTop = alwaysOnTop.state == .on
        case allDesktops: Settings.allDesktops = allDesktops.state == .on
        case closeWhenEmpty: Settings.closeWhenEmpty = closeWhenEmpty.state == .on
        case playSound:
            Settings.playSound = playSound.state == .on
            if Settings.playSound { ShelfPanel.openSound?.play() }
        default: break
        }
    }

    @objc private func restoreDefaults() {
        ["ShakeEnabled", "ShakeSensitivityLevel", "ShakeSensitivity", "ShakeModifier", "ShelfPlacement",
         "ShelfAlwaysOnTop", "ShelfAllDesktops", "ShelfCloseWhenEmpty", "ShelfPlaySound"]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
        Settings.registerDefaults()
        NotificationCenter.default.post(name: Settings.didChange, object: nil)
    }

    private static func describe(_ value: Double) -> String {
        switch value {
        case ..<0.2: return "Very Low"
        case ..<0.4: return "Low"
        case ..<0.6: return "Medium"
        case ..<0.8: return "High"
        default: return "Very High"
        }
    }

    private func label(_ text: String) -> NSTextField { NSTextField(labelWithString: text) }

    private func small(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 11)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func note(_ text: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: 11)
        field.textColor = .secondaryLabelColor
        field.preferredMaxLayoutWidth = 340
        return field
    }

    private func spacer() -> NSView {
        let view = NSView()
        view.heightAnchor.constraint(equalToConstant: 4).isActive = true
        return view
    }
}
