import AppKit

enum ClipboardImage {
    private static let fileReferenceTypes: Set<NSPasteboard.PasteboardType> = [
        .fileURL,
        NSPasteboard.PasteboardType("NSFilenamesPboardType"),
        NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")
    ]

    static func read(from pasteboard: NSPasteboard = .general) -> NSImage? {
        // Finder includes image previews alongside file URLs. A file copy must
        // retain its native paste behavior (path or attachment), so file
        // references always take precedence over image representations.
        guard !containsFileReference(in: pasteboard) else { return nil }

        if let image = NSImage(pasteboard: pasteboard), image.isValid {
            return image
        }

        let imageClasses: [AnyClass] = [NSImage.self]
        if let image = pasteboard.readObjects(
            forClasses: imageClasses,
            options: nil
        )?.first as? NSImage {
            return image
        }

        return nil
    }

    private static func containsFileReference(in pasteboard: NSPasteboard) -> Bool {
        let types = Set(pasteboard.types ?? [])
        if !types.isDisjoint(with: fileReferenceTypes) {
            return true
        }

        return pasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }

    static func write(pngData: Data) -> Bool {
        guard let image = NSImage(data: pngData) else { return false }

        let item = NSPasteboardItem()
        item.setData(pngData, forType: .png)
        if let tiff = image.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }
}
