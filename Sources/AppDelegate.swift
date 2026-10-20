import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let shakeDetector = ShakeDetector()
    private var shelves: [ShelfPanel] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuBarIcon.make()

        let menu = NSMenu()
        menu.addItem(withTitle: "New Shelf", action: #selector(newShelfFromMenu), keyEquivalent: "n").target = self
        menu.addItem(withTitle: "Close All Shelves", action: #selector(closeAllShelves), keyEquivalent: "").target = self
        menu.addItem(.separator())

        let sensitivity = NSMenuItem(title: "Shake Sensitivity", action: nil, keyEquivalent: "")
        let sensitivityMenu = NSMenu()
        for level in ShakeDetector.Sensitivity.allCases {
            let item = NSMenuItem(title: level.title, action: #selector(setSensitivity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = level.rawValue
            item.state = level == shakeDetector.sensitivity ? .on : .off
            sensitivityMenu.addItem(item)
        }
        sensitivity.submenu = sensitivityMenu
        menu.addItem(sensitivity)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Shelfy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        shakeDetector.onShake = { [weak self] point in self?.showShelf(near: point) }
        shakeDetector.start()

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

    @objc private func setSensitivity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int,
              let level = ShakeDetector.Sensitivity(rawValue: raw) else { return }
        shakeDetector.sensitivity = level
        sender.menu?.items.forEach { $0.state = $0 == sender ? .on : .off }
    }
}
