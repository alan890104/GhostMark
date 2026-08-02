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

    static func read(from pasteboard: NSPasteboard = .general) -> NSImage? {
        let types = Set(pasteboard.types ?? [])

        // A readable local file URL represents a file paste. Finder may also
        // advertise image preview data, but the file semantics must win so the
        // destination can receive its native path or attachment behavior.
        guard !containsFileReference(pasteboard, types: types) else { return nil }

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

    private static func containsFileReference(
        _ pasteboard: NSPasteboard,
        types: Set<NSPasteboard.PasteboardType>
    ) -> Bool {
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
