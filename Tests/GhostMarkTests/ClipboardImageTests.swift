import AppKit
import Testing
@testable import GhostMark

struct ClipboardImageTests {
    @MainActor
    @Test("Finder image-file copies keep their native paste behavior")
    func finderImageFileIsNotReadAsClipboardImage() throws {
        let pasteboard = makePasteboard()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GhostMarkTests-\(UUID().uuidString).png")
        try pngData().write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let item = NSPasteboardItem()
        item.setString(fileURL.absoluteString, forType: .fileURL)
        #expect(pasteboard.writeObjects([item]))

        #expect(ClipboardImage.read(from: pasteboard) == nil)
    }

    @MainActor
    @Test("Finder markers keep file copies native even when a preview is present")
    func finderFileWithPreviewIsNotReadAsClipboardImage() throws {
        let pasteboard = makePasteboard()
        let item = NSPasteboardItem()
        item.setString("finder-item", forType: NSPasteboard.PasteboardType("com.apple.finder.node"))
        item.setString("file:///Users/example/Desktop/reference.png", forType: .fileURL)
        item.setData(try pngData(), forType: .png)
        #expect(pasteboard.writeObjects([item]))

        #expect(ClipboardImage.read(from: pasteboard) == nil)
    }

    @MainActor
    @Test("Copy Image data wins over an accompanying temporary file URL")
    func bitmapWithTemporaryFileURLIsReadAsClipboardImage() throws {
        let pasteboard = makePasteboard()
        let item = NSPasteboardItem()
        item.setString("file:///private/tmp/telegram-image.png", forType: .fileURL)
        item.setData(try pngData(), forType: .png)
        #expect(pasteboard.writeObjects([item]))

        #expect(ClipboardImage.read(from: pasteboard)?.isValid == true)
    }

    @MainActor
    @Test("Pure bitmap copies still open in GhostMark")
    func pureBitmapIsReadAsClipboardImage() throws {
        let pasteboard = makePasteboard()
        let item = NSPasteboardItem()
        item.setData(try pngData(), forType: .png)
        #expect(pasteboard.writeObjects([item]))

        #expect(ClipboardImage.read(from: pasteboard)?.isValid == true)
    }

    @MainActor
    @Test("A web source URL does not make copied bitmap content a file copy")
    func bitmapWithWebSourceURLIsReadAsClipboardImage() throws {
        let pasteboard = makePasteboard()
        let item = NSPasteboardItem()
        item.setString("https://example.com/reference.png", forType: .URL)
        item.setData(try pngData(), forType: .png)
        #expect(pasteboard.writeObjects([item]))

        #expect(ClipboardImage.read(from: pasteboard)?.isValid == true)
    }

    @MainActor
    private func makePasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("GhostMarkTests.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        return pasteboard
    }

    @MainActor
    private func pngData() throws -> Data {
        let image = NSImage(size: NSSize(width: 2, height: 2), flipped: false) { rect in
            NSColor.systemPink.setFill()
            rect.fill()
            return true
        }
        let tiff = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiff))
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }
}
