import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let shakeDetector = ShakeDetector()
    private var shelves: [ShelfPanel] = []
    private lazy var settingsWindow = SettingsWindow()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuBarIcon.make()

        let menu = NSMenu()
        menu.addItem(withTitle: "New Shelf", action: #selector(newShelfFromMenu), keyEquivalent: "n").target = self
        menu.addItem(withTitle: "Close All Shelves", action: #selector(closeAllShelves), keyEquivalent: "").target = self
        menu.addItem(.separator())

        let shake = NSMenuItem(title: "Shake to Open", action: #selector(toggleShake), keyEquivalent: "")
        shake.target = self
        menu.addItem(shake)
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Shelfy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self
        statusItem.menu = menu

        shakeDetector.onShake = { [weak self] point in self?.showShelf(near: point) }
        shakeDetector.start()

        // For screenshots: SHELFY_SETTINGS_SNAPSHOT=/path.png saves the Settings window.
        if let path = ProcessInfo.processInfo.environment["SHELFY_SETTINGS_SNAPSHOT"] {
            settingsWindow.present()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in settingsWindow.snapshot(to: path) }
        }

        // For testing: SHELFY_DEMO_FILES="/a:/b" opens a shelf holding those files.
        if let demo = ProcessInfo.processInfo.environment["SHELFY_DEMO_FILES"] {
            let shelf = makeShelf()
            shelf.show(near: NSPoint(x: 400, y: 600))
            shelf.add(demo.split(separator: ":").map { URL(fileURLWithPath: String($0)) })
            if let path = ProcessInfo.processInfo.environment["SHELFY_DEMO_SNAPSHOT"] {
                // Give Quick Look previews time to load first.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { shelf.snapshot(to: path) }
            }
        }
    }

    /// Reuse an empty shelf if one is open, otherwise make a new one.
    func showShelf(near point: NSPoint) {
        shelves.removeAll { !$0.isVisible }
        let shelf = shelves.first { $0.isEmpty } ?? makeShelf()
        shelf.show(near: point)
    }

    private func makeShelf() -> ShelfPanel {
        let shelf = ShelfPanel()
        shelves.append(shelf)
        return shelf
    }

    @objc private func newShelfFromMenu() {
        showShelf(near: NSEvent.mouseLocation)
    }

    @objc private func closeAllShelves() {
        shelves.forEach { $0.close() }
        shelves.removeAll()
    }

    @objc private func toggleShake() {
        Settings.shakeEnabled.toggle()
    }

    @objc private func openSettings() {
        settingsWindow.present()
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.item(withTitle: "Shake to Open")?.state = Settings.shakeEnabled ? .on : .off
    }
}
