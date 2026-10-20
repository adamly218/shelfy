import AppKit
import QuickLookThumbnailing

/// File details and Quick Look previews for the shelf.
enum FileInfo {
    private static let cache = NSCache<NSString, NSImage>()

    /// "1.2 MB · PNG image", or the kind alone for folders.
    static func subtitle(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .localizedTypeDescriptionKey])
        let kind = values?.localizedTypeDescription
        if values?.isDirectory == true { return kind ?? "Folder" }
        let size = ByteCountFormatter.string(fromByteCount: Int64(values?.fileSize ?? 0), countStyle: .file)
        return kind.map { "\(size) · \($0)" } ?? size
    }

    /// Combined size of the files (folders aren't counted).
    static func totalSize(of urls: [URL]) -> String {
        let bytes = urls.reduce(Int64(0)) { sum, url in
            sum + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Best image available right now: a cached preview, or the file's icon.
    static func image(for url: URL, size: CGFloat) -> NSImage {
        cache.object(forKey: key(url, size)) ?? NSWorkspace.shared.icon(forFile: url.path)
    }

    /// Calls `update` with the file icon right away, then again with a Quick Look
    /// preview (rounded, for photos, PDFs, videos…) once one is ready.
    static func loadImage(for url: URL, size: CGFloat, update: @escaping (NSImage) -> Void) {
        let key = key(url, size)
        if let cached = cache.object(forKey: key) { update(cached); return }
        update(NSWorkspace.shared.icon(forFile: url.path))

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: size, height: size),
                                                   scale: scale, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
            guard let thumbnail else { return } // no preview: keep the icon
            let image = rounded(thumbnail.nsImage)
            DispatchQueue.main.async {
                cache.setObject(image, forKey: key)
                update(image)
            }
        }
    }

    private static func key(_ url: URL, _ size: CGFloat) -> NSString { "\(url.path)#\(size)" as NSString }

    /// Rounds a preview's corners and adds a hairline border, like Finder.
    private static func rounded(_ image: NSImage) -> NSImage {
        let size = image.size
        let radius = max(3, min(size.width, size.height) * 0.08)
        return NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            image.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()
            NSColor.black.withAlphaComponent(0.15).setStroke()
            let border = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
            border.lineWidth = 1
            border.stroke()
            return true
        }
    }
}
