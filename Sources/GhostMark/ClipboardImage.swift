import AppKit

enum ClipboardImage {
    private static let explicitImageTypes = Set(
        NSImage.imageTypes.map { NSPasteboard.PasteboardType($0) }
    ).union([
        .png,
        .tiff,
        NSPasteboard.PasteboardType("Apple PNG pasteboard type"),
        NSPasteboard.PasteboardType("NeXT TIFF v4.0 pasteboard type")
    ])

    private static let explicitFileCopyTypes: Set<NSPasteboard.PasteboardType> = [
        NSPasteboard.PasteboardType("com.apple.finder.node")
    ]

    static func read(from pasteboard: NSPasteboard = .general) -> NSImage? {
        let types = Set(pasteboard.types ?? [])

        // "Copy Image" sources can include a temporary file URL alongside the
        // bitmap. Prefer explicit image data unless the pasteboard identifies
        // itself as a real file copy (for example, Finder).
        guard !isFileCopy(pasteboard, types: types) else { return nil }

        for type in pasteboard.types ?? [] where explicitImageTypes.contains(type) {
            if
                let data = pasteboard.data(forType: type),
                let image = NSImage(data: data),
                image.isValid
            {
                return image
            }
        }

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

    private static func isFileCopy(
        _ pasteboard: NSPasteboard,
        types: Set<NSPasteboard.PasteboardType>
    ) -> Bool {
        if !types.isDisjoint(with: explicitFileCopyTypes) {
            return true
        }

        if !types.isDisjoint(with: explicitImageTypes) {
            return false
        }

        if types.contains(.fileURL) {
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
