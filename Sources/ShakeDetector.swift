import AppKit

/// Watches mouse drags in other apps. When the user is dragging files and
/// shakes the cursor left-right a few times, `onShake` fires with the cursor position.
///
/// A drag counts as a file drag when the system drag pasteboard changed since
/// the mouse went down and it holds file URLs. Global mouse monitors don't need
/// Accessibility permission.
final class ShakeDetector {
    enum Sensitivity: Int, CaseIterable {
        case normal, high, veryHigh

        var title: String {
            switch self {
            case .normal: return "Normal"
            case .high: return "High"
            case .veryHigh: return "Very High"
            }
        }

        /// Minimum horizontal travel (points) for a stroke to count.
        var minStroke: CGFloat {
            switch self {
            case .normal: return 60
            case .high: return 40
            case .veryHigh: return 25
            }
        }

        /// Direction changes needed inside the time window.
        var reversalsNeeded: Int { self == .normal ? 4 : 3 }
    }

    var onShake: ((NSPoint) -> Void)?
    var sensitivity: Sensitivity {
        get { Sensitivity(rawValue: UserDefaults.standard.integer(forKey: "ShakeSensitivity")) ?? .normal }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "ShakeSensitivity") }
    }

    private let window: TimeInterval = 0.8
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
        guard !firedThisDrag else { return }

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
            if direction != 0, abs(x - strokeStartX) >= sensitivity.minStroke {
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
        if reversals.count >= sensitivity.reversalsNeeded {
            firedThisDrag = true
            onShake?(NSEvent.mouseLocation)
        }
    }
}
