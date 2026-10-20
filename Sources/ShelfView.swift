import AppKit

/// Drop files on it to hold them. With one file it shows a large preview; with
/// two or more it lists each file so you can drag them out one at a time, plus
/// a "Drag all" row that takes everything at once.
final class ShelfView: NSView {
    private(set) var items: [URL] = [] { didSet { refresh() } }
    /// Called when the item count changes, so the window can resize.
    var onItemsChanged: (() -> Void)?
    /// Called when the last file has been dragged out or removed.
    var onEmptied: (() -> Void)?

    static let rowHeight: CGFloat = 46
    static let maxVisibleRows = 6

    /// Size that fits the current contents (the panel adds its header on top).
    var preferredSize: NSSize {
        switch items.count {
        case 0: return NSSize(width: 180, height: 150)
        case 1: return NSSize(width: 180, height: 172)
        default:
            let rows = CGFloat(min(items.count, Self.maxVisibleRows))
            // "Drag all" row + gap + file rows + bottom padding
            return NSSize(width: 280, height: 56 + 8 + rows * Self.rowHeight + 8)
        }
    }

    /// "Shelf", or "3 items · 12 MB".
    var summary: String {
        guard !items.isEmpty else { return "Shelf" }
        let count = items.count == 1 ? "1 item" : "\(items.count) items"
        return "\(count) · \(FileInfo.totalSize(of: items))"
    }

    private let emptyView = EmptyDropView()
    private let singleView = DraggableFilesView()
    private let singleIcon = NSImageView()
    private let singleText = NSStackView()

    private let listView = NSView()
    private let dragAllContainer = NSView()
    private let rowsStack = NSStackView()

    private let dropHighlight = DropHighlightView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
        pin(emptyView)
        setUpSingleView()
        setUpListView()
        pin(dropHighlight)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func clear() { items.removeAll() }

    /// Adds files not already on the shelf. Returns whether anything was added.
    @discardableResult
    func add(_ urls: [URL]) -> Bool {
        let new = urls.filter { !items.contains($0) }
        guard !new.isEmpty else { return false }
        items.append(contentsOf: new)
        onItemsChanged?()
        return true
    }

    private func remove(_ urls: [URL]) {
        items.removeAll { urls.contains($0) }
        onItemsChanged?()
        if items.isEmpty { onEmptied?() }
    }

    // MARK: Layout

    private func setUpSingleView() {
        singleIcon.imageScaling = .scaleProportionallyUpOrDown
        singleIcon.unregisterDraggedTypes() // let drops reach the shelf instead
        singleIcon.shadow = softShadow(blur: 8, opacity: 0.25)

        singleText.orientation = .vertical
        singleText.alignment = .centerX
        singleText.spacing = 2

        singleView.urlsToDrag = { [unowned self] in items }
        singleView.onDragSucceeded = { [unowned self] in remove($0) }
        pin(singleView)
        for view in [singleIcon, singleText] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            singleView.addSubview(view)
        }
        NSLayoutConstraint.activate([
            singleIcon.centerXAnchor.constraint(equalTo: singleView.centerXAnchor),
            singleIcon.topAnchor.constraint(equalTo: singleView.topAnchor, constant: 4),
            singleIcon.widthAnchor.constraint(equalToConstant: 96),
            singleIcon.heightAnchor.constraint(equalToConstant: 96),
            singleText.topAnchor.constraint(equalTo: singleIcon.bottomAnchor, constant: 10),
            singleText.leadingAnchor.constraint(equalTo: singleView.leadingAnchor, constant: 12),
            singleText.trailingAnchor.constraint(equalTo: singleView.trailingAnchor, constant: -12),
        ])
    }

    private func setUpListView() {
        pin(listView)

        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 0
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rowsStack)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = document

        for view in [dragAllContainer, scrollView] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            listView.addSubview(view)
        }
        NSLayoutConstraint.activate([
            dragAllContainer.topAnchor.constraint(equalTo: listView.topAnchor),
            dragAllContainer.leadingAnchor.constraint(equalTo: listView.leadingAnchor, constant: 8),
            dragAllContainer.trailingAnchor.constraint(equalTo: listView.trailingAnchor, constant: -8),
            dragAllContainer.heightAnchor.constraint(equalToConstant: 56),

            scrollView.topAnchor.constraint(equalTo: dragAllContainer.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: listView.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: listView.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: listView.bottomAnchor, constant: -8),

            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            rowsStack.topAnchor.constraint(equalTo: document.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])
    }

    private func pin(_ view: NSView, to container: NSView? = nil) {
        let container = container ?? self
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    private func refresh() {
        emptyView.isHidden = !items.isEmpty
        singleView.isHidden = items.count != 1
        listView.isHidden = items.count < 2
        if items.count == 1 { refreshSingle() }
        if items.count > 1 { refreshList() }
    }

    private func refreshSingle() {
        let url = items[0]
        FileInfo.loadImage(for: url, size: 192) { [weak self] in self?.singleIcon.image = $0 }
        singleText.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let text = makeTitleStack(title: url.lastPathComponent, subtitle: FileInfo.subtitle(for: url))
        text.alignment = .centerX
        text.arrangedSubviews.compactMap { $0 as? NSTextField }.forEach { $0.alignment = .center }
        singleText.addArrangedSubview(text)
        singleView.toolTip = url.path
    }

    private func refreshList() {
        dragAllContainer.subviews.forEach { $0.removeFromSuperview() }
        let all = DragAllRow(urls: items)
        all.urlsToDrag = { [unowned self] in items }
        all.onDragSucceeded = { [unowned self] in remove($0) }
        pin(all, to: dragAllContainer)

        // One row per file: each drags out on its own.
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for url in items {
            let row = ShelfItemRow(url: url)
            row.urlsToDrag = { [url] }
            row.onDragSucceeded = { [unowned self] in remove($0) }
            row.onRemove = { [unowned self] in remove([$0]) }
            rowsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
        }
    }

    // MARK: Dropping in

    private func fileURLs(from info: NSDraggingInfo) -> [URL] {
        info.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                            options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Ignore drags that started from this shelf.
        guard (sender.draggingSource as? NSView)?.window !== window, !fileURLs(from: sender).isEmpty else { return [] }
        dropHighlight.setVisible(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { dropHighlight.setVisible(false) }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropHighlight.setVisible(false)
        return add(fileURLs(from: sender))
    }
}

/// Dashed drop zone shown while the shelf is empty.
private final class EmptyDropView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        let symbol = NSImageView(image: NSImage(systemSymbolName: "arrow.down.doc", accessibilityDescription: nil)!)
        symbol.symbolConfiguration = .init(pointSize: 26, weight: .light).applying(.init(hierarchicalColor: .secondaryLabelColor))
        let label = NSTextField(labelWithString: "Drop files here")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [symbol, label])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 12, dy: 12).offsetBy(dx: 0, dy: 2), xRadius: 14, yRadius: 14)
        path.lineWidth = 1.5
        path.setLineDash([5, 4], count: 2, phase: 0)
        NSColor.tertiaryLabelColor.setStroke()
        path.stroke()
    }
}

/// Accent-colored outline that fades in while files hover over the shelf.
private final class DropHighlightView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        alphaValue = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func setVisible(_ visible: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            animator().alphaValue = visible ? 1 : 0
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 6), xRadius: 16, yRadius: 16)
        NSColor.controlAccentColor.withAlphaComponent(0.1).setFill()
        path.fill()
        path.lineWidth = 2
        NSColor.controlAccentColor.setStroke()
        path.stroke()
    }
}

/// Top-down coordinates so the file list starts at the top of the scroll view.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
