import AppKit

/// A view you can drag files out of. Subclasses decide which files and where
/// the drag image starts; `onDragSucceeded` fires once the files land somewhere.
class DraggableFilesView: NSView, NSDraggingSource {
    var urlsToDrag: () -> [URL] = { [] }
    var onDragSucceeded: (([URL]) -> Void)?

    /// Where the drag image starts, in this view's coordinates.
    var dragImageFrame: NSRect { NSRect(x: 4, y: (bounds.height - 32) / 2, width: 32, height: 32) }

    private var mouseDownEvent: NSEvent?
    private var draggedURLs: [URL] = []

    // Clicking here drags files, not the shelf window.
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) { mouseDownEvent = event }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownEvent else { return }
        let moved = hypot(event.locationInWindow.x - start.locationInWindow.x,
                          event.locationInWindow.y - start.locationInWindow.y)
        guard moved > 3 else { return }
        mouseDownEvent = nil

        draggedURLs = urlsToDrag()
        guard !draggedURLs.isEmpty else { return }
        let frame = dragImageFrame
        let items = draggedURLs.enumerated().map { index, url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let offset = CGFloat(min(index, 4)) * 4
            item.setDraggingFrame(frame.offsetBy(dx: offset, dy: -offset),
                                  contents: FileInfo.image(for: url, size: 96))
            return item
        }
        beginDraggingSession(with: items, event: event, source: self).animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        // Double-click opens the files.
        if event.clickCount == 2 { urlsToDrag().forEach { NSWorkspace.shared.open($0) } }
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .link, .generic] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // An empty operation means the drop was cancelled or refused.
        guard !operation.isEmpty else { return }
        onDragSucceeded?(draggedURLs)
    }
}

/// A rounded row that lightens on hover.
class HoverRow: DraggableFilesView {
    var baseColor: NSColor? { nil }
    var hoverColor: NSColor { NSColor.labelColor.withAlphaComponent(0.08) }
    private var isHovered = false { didSet { updateBackground() } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        updateBackground()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }

    private func updateBackground() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = (isHovered ? hoverColor : baseColor)?.cgColor
            }
        }
    }
}

/// A soft drop shadow falling slightly downward.
func softShadow(blur: CGFloat, opacity: CGFloat) -> NSShadow {
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: -1)
    shadow.shadowColor = NSColor.black.withAlphaComponent(opacity)
    return shadow
}

/// Builds a title + subtitle label pair stacked vertically.
func makeTitleStack(title: String, subtitle: String, titleWeight: NSFont.Weight = .medium) -> NSStackView {
    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = .systemFont(ofSize: 13, weight: titleWeight)
    titleLabel.lineBreakMode = .byTruncatingMiddle
    let subtitleLabel = NSTextField(labelWithString: subtitle)
    subtitleLabel.font = .systemFont(ofSize: 11)
    subtitleLabel.textColor = .secondaryLabelColor
    subtitleLabel.lineBreakMode = .byTruncatingTail
    for label in [titleLabel, subtitleLabel] {
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    let stack = NSStackView(views: [titleLabel, subtitleLabel])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 1
    return stack
}

/// One file in the shelf's list: preview, name and "size · kind".
final class ShelfItemRow: HoverRow {
    let url: URL
    var onRemove: ((URL) -> Void)?

    private let iconView = NSImageView()

    init(url: URL) {
        self.url = url
        super.init(frame: .zero)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.unregisterDraggedTypes()
        FileInfo.loadImage(for: url, size: 64) { [weak iconView] in iconView?.image = $0 }
        let text = makeTitleStack(title: url.lastPathComponent, subtitle: FileInfo.subtitle(for: url))

        for view in [iconView, text] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: ShelfView.rowHeight),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            text.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            text.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        toolTip = url.path
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var dragImageFrame: NSRect { iconView.frame }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open", action: #selector(openFile), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Show in Finder", action: #selector(showInFinder), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Remove from Shelf", action: #selector(remove), keyEquivalent: "").target = self
        return menu
    }

    @objc private func openFile() { NSWorkspace.shared.open(url) }
    @objc private func showInFinder() { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    @objc private func remove() { onRemove?(url) }
}

/// The top row of a multi-file shelf: a fanned stack of previews that drags every file at once.
final class DragAllRow: HoverRow {
    override var baseColor: NSColor? { NSColor.controlAccentColor.withAlphaComponent(0.14) }
    override var hoverColor: NSColor { NSColor.controlAccentColor.withAlphaComponent(0.24) }

    private let stackView = NSView()

    init(urls: [URL]) {
        super.init(frame: .zero)

        // Up to three previews, fanned out like a hand of cards.
        let angles: [CGFloat] = [-9, 9, 0]
        for (index, url) in urls.prefix(3).reversed().enumerated() {
            let card = NSImageView(frame: NSRect(x: 4, y: 4, width: 32, height: 32))
            card.imageScaling = .scaleProportionallyUpOrDown
            card.unregisterDraggedTypes()
            card.shadow = softShadow(blur: 3, opacity: 0.3)
            FileInfo.loadImage(for: url, size: 64) { [weak card] in card?.image = $0 }
            card.frameCenterRotation = urls.count == 1 ? 0 : angles[(index + 3 - min(urls.count, 3)) % 3]
            stackView.addSubview(card)
        }

        let text = makeTitleStack(title: "Drag all \(urls.count) files",
                                  subtitle: FileInfo.totalSize(of: urls), titleWeight: .semibold)
        let arrow = NSImageView(image: NSImage(systemSymbolName: "hand.draw", accessibilityDescription: nil)!)
        arrow.contentTintColor = .controlAccentColor
        arrow.symbolConfiguration = .init(pointSize: 14, weight: .medium)

        for view in [stackView, text, arrow] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 56),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.widthAnchor.constraint(equalToConstant: 40),
            stackView.heightAnchor.constraint(equalToConstant: 40),
            text.leadingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 10),
            text.trailingAnchor.constraint(lessThanOrEqualTo: arrow.leadingAnchor, constant: -8),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            arrow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            arrow.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        toolTip = "Drag to move all files together"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var dragImageFrame: NSRect { stackView.frame.insetBy(dx: 4, dy: 4) }
}
