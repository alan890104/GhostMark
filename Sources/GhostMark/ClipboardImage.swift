import AppKit

enum ClipboardImage {
    static func read() -> NSImage? {
        let pasteboard = NSPasteboard.general

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

        let urlClasses: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: NSImage.imageTypes
        ]
        if
            let url = pasteboard.readObjects(
                forClasses: urlClasses,
                options: options
            )?.first as? URL,
            let image = NSImage(contentsOf: url)
        {
            return image
        }

        return nil
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
