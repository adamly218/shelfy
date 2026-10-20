import AppKit

/// A small floating glass window that holds files. It doesn't take focus from
/// the app you're dragging from, and it stays visible across Spaces and full-screen apps.
final class ShelfPanel: NSPanel {
    private static let headerHeight: CGFloat = 34
    private static let cornerRadius: CGFloat = 24
    static let openSound = NSSound(named: "Pop")

    private let shelfView = ShelfView()
    private let header = ShelfHeaderView()

    var isEmpty: Bool { shelfView.items.isEmpty }

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: .zero),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        applySettings()
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        let container = NSView()
        for view in [header, shelfView] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: Self.headerHeight),
            shelfView.topAnchor.constraint(equalTo: header.bottomAnchor),
            shelfView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            shelfView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            shelfView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = Self.makeBackground(containing: container)
        setContentSize(fittingSize)

        header.onClose = { [weak self] in self?.animateClose() }
        shelfView.onItemsChanged = { [weak self] in self?.contentsChanged() }
        shelfView.onEmptied = { [weak self] in
            if Settings.closeWhenEmpty { self?.animateClose() }
        }
        contentsChanged()
        NotificationCenter.default.addObserver(self, selector: #selector(applySettings), name: Settings.didChange, object: nil)
    }

    @objc private func applySettings() {
        level = Settings.alwaysOnTop ? .floating : .normal
        collectionBehavior = Settings.allDesktops
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.moveToActiveSpace, .fullScreenAuxiliary]
    }

    /// Liquid Glass on macOS 26+, frosted blur before that.
    private static func makeBackground(containing container: NSView) -> NSView {
        container.autoresizingMask = [.width, .height]
        // Test snapshots can't capture glass, so draw a plain background instead.
        if ProcessInfo.processInfo.environment["SHELFY_DEMO_SNAPSHOT"] != nil {
            let plain = NSView()
            plain.wantsLayer = true
            plain.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1).cgColor
            plain.layer?.cornerRadius = cornerRadius
            container.frame = plain.bounds
            plain.addSubview(container)
            return plain
        }
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.contentView = container
            return glass
        }
        let blur = NSVisualEffectView()
        blur.material = .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = cornerRadius
        blur.layer?.cornerCurve = .continuous
        blur.layer?.masksToBounds = true
        container.frame = blur.bounds
        blur.addSubview(container)
        return blur
    }

    private var fittingSize: NSSize {
        let size = shelfView.preferredSize
        return NSSize(width: size.width, height: size.height + Self.headerHeight)
    }

    func add(_ urls: [URL]) { shelfView.add(urls) }

    /// Saves a PNG of the shelf's contents (used for testing the layout).
    /// The glass background itself isn't captured this way.
    func snapshot(to path: String) {
        guard let view = contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    private func contentsChanged() {
        header.title = shelfView.summary
        fitToContent()
    }

    /// Resize for the current contents, keeping the top edge where it is.
    private func fitToContent() {
        let size = fittingSize
        guard size != frame.size else { return }
        var newFrame = frame
        newFrame.origin.y += frame.height - size.height
        newFrame.size = size
        if let visible = screen?.visibleFrame {
            newFrame.origin.y = max(newFrame.origin.y, visible.minY)
            newFrame.origin.x = min(newFrame.origin.x, visible.maxX - size.width)
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(newFrame, display: true)
        } completionHandler: { [weak self] in
            self?.invalidateShadow()
        }
    }

    func show(near point: NSPoint) {
        // Place the shelf where Settings says, kept on screen.
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        var origin: NSPoint
        switch Settings.placement {
        case .besideCursor: origin = NSPoint(x: point.x + 40, y: point.y - frame.height / 2)
        case .underCursor: origin = NSPoint(x: point.x - frame.width / 2, y: point.y - frame.height / 2)
        case .screenCenter:
            let visible = screen?.visibleFrame ?? .zero
            origin = NSPoint(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2)
        }
        if let visible = screen?.visibleFrame {
            if Settings.placement == .besideCursor, origin.x + frame.width > visible.maxX {
                origin.x = point.x - 40 - frame.width
            }
            origin.x = min(max(origin.x, visible.minX), visible.maxX - frame.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - frame.height)
        }

        // Fade in while rising slightly into place.
        let target = NSRect(origin: origin, size: frame.size)
        setFrame(target.offsetBy(dx: 0, dy: -10), display: false)
        alphaValue = 0
        orderFrontRegardless()
        if Settings.playSound { Self.openSound?.play() }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            animator().setFrame(target, display: true)
        }
    }

    /// Fade out, then close.
    func animateClose() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.close()
            self?.alphaValue = 1
        }
    }

    override func close() {
        shelfView.clear()
        contentsChanged()
        super.close()
    }
}

/// Close button, centered title, and a grab area for moving the shelf.
private final class ShelfHeaderView: NSView {
    var onClose: (() -> Void)?
    var title: String {
        get { titleLabel.stringValue }
        set { titleLabel.stringValue = newValue }
    }

    private let titleLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)

        let close = NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")!,
                             target: self, action: #selector(closeTapped))
        close.isBordered = false
        close.symbolConfiguration = .init(pointSize: 15, weight: .regular)
            .applying(.init(hierarchicalColor: .tertiaryLabelColor))
        close.toolTip = "Close shelf"

        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        for view in [close, titleLabel] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            close.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            close.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: close.trailingAnchor, constant: 8),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func closeTapped() { onClose?() }
}
