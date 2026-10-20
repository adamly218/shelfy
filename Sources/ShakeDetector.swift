import AppKit

/// Watches mouse drags in other apps. When the user is dragging files and
/// shakes the cursor left-right a few times, `onShake` fires with the cursor position.
///
/// A drag counts as a file drag when the system drag pasteboard changed since
/// the mouse went down and it holds file URLs. Global mouse monitors don't need
/// Accessibility permission.
final class ShakeDetector {
    var onShake: ((NSPoint) -> Void)?

    // Tuning from Settings.sensitivity: 0 = big shake needed, 1 = small wiggle is enough.
    /// Minimum horizontal travel (points) for a stroke to count.
    private var minStroke: CGFloat { 90 - 70 * CGFloat(Settings.sensitivity) }
    /// Direction changes needed inside the time window.
    private var reversalsNeeded: Int { Settings.sensitivity < 0.5 ? 4 : 3 }
    /// How long (seconds) the reversals may take.
    private var window: TimeInterval { 0.7 + 0.3 * Settings.sensitivity }

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var monitors: [Any] = []

    private var changeCountAtMouseDown = 0
    private var isFileDrag: Bool?
    private var direction: CGFloat = 0
    private var strokeStartX: CGFloat = 0
    private var lastX: CGFloat = 0
    private var reversals: [TimeInterval] = []
    private var firedThisDrag = false

    func start() {
        let down = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in self?.mouseDown() }
        let drag = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in self?.mouseDragged() }
        let up = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in self?.reset() }
        monitors = [down, drag, up].compactMap { $0 }
    }

    private func mouseDown() {
        changeCountAtMouseDown = dragPasteboard.changeCount
        reset()
    }

    private func reset() {
        isFileDrag = nil
        direction = 0
        reversals.removeAll()
        firedThisDrag = false
        lastX = NSEvent.mouseLocation.x
        strokeStartX = lastX
    }

    private func mouseDragged() {
        guard !firedThisDrag, Settings.shakeEnabled else { return }
        if let flag = Settings.modifier.flag, !NSEvent.modifierFlags.contains(flag) { return }

        // The drag pasteboard fills a moment after the drag starts, so keep checking until it does.
        if isFileDrag != true {
            guard dragPasteboard.changeCount != changeCountAtMouseDown else { return }
            isFileDrag = dragPasteboard.canReadObject(forClasses: [NSURL.self],
                                                      options: [.urlReadingFileURLsOnly: true])
        }
        guard isFileDrag == true else { return }

        let x = NSEvent.mouseLocation.x
        let delta = x - lastX
        lastX = x
        guard abs(delta) > 0.5 else { return }

        let newDirection: CGFloat = delta > 0 ? 1 : -1
        if newDirection != direction {
            // Only count a reversal if the stroke before it was long enough.
            if direction != 0, abs(x - strokeStartX) >= minStroke {
                registerReversal()
            }
            direction = newDirection
            strokeStartX = x
        }
    }

    private func registerReversal() {
        let now = ProcessInfo.processInfo.systemUptime
        reversals.append(now)
        reversals.removeAll { now - $0 > window }
        if reversals.count >= reversalsNeeded {
            firedThisDrag = true
            onShake?(NSEvent.mouseLocation)
        }
    }
}
