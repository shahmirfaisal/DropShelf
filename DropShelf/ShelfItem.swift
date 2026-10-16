import AppKit
import UniformTypeIdentifiers

/// One thing sitting on a shelf.
/// Not tied to the main thread, so dropped items can be read in the background.
nonisolated struct ShelfItem: Identifiable, Equatable {
    enum Content: Equatable {
        case file(URL)
        case text(String)
        case link(URL)
    }

    let id = UUID()
    let content: Content

    var title: String {
        switch content {
        case .file(let url): url.lastPathComponent
        case .text(let text):
            text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
        case .link(let url): url.host ?? url.absoluteString
        }
    }

    var subtitle: String {
        switch content {
        case .file(let url): url.deletingLastPathComponent().path
        case .text(let text): "\(text.count) characters"
        case .link(let url): url.absoluteString
        }
    }

    /// What gets put on the drag pasteboard when this item is dragged out.
    var pasteboardWriter: NSPasteboardWriting {
        switch content {
        case .file(let url): return url as NSURL
        case .text(let text): return text as NSString
        case .link(let url): return url as NSURL
        }
    }

    var fileURL: URL? {
        if case .file(let url) = content { return url }
        return nil
    }

    var icon: NSImage {
        switch content {
        case .file(let url): NSWorkspace.shared.icon(forFile: url.path)
        case .text: NSWorkspace.shared.icon(for: .plainText)
        case .link: NSImage(systemSymbolName: "link", accessibilityDescription: nil) ?? NSImage()
        }
    }

    // MARK: Reading dropped content

    /// Turns whatever was dropped into shelf items. Images without a file
    /// (e.g. dragged from a web page) are saved as PNG files first.
    static func items(from pasteboard: NSPasteboard) -> [ShelfItem] {
        // 1. Files
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return urls.map { ShelfItem(content: .file($0)) }
        }
        // 2. Images without a file
        if let image = NSImage(pasteboard: pasteboard),
           (pasteboard.types ?? []).contains(where: { [.png, .tiff].contains($0) }),
           let url = saveImage(image) {
            return [ShelfItem(content: .file(url))]
        }
        // 3. Web links
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first, let scheme = url.scheme, ["http", "https"].contains(scheme) {
            return [ShelfItem(content: .link(url))]
        }
        // 4. Text
        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [ShelfItem(content: .text(text))]
        }
        return []
    }

    /// Dropped images are kept in ~/Library/Caches/DropShelf/
    static let imagesFolder: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("DropShelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func saveImage(_ image: NSImage) -> URL? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = imagesFolder.appendingPathComponent("Image \(formatter.string(from: Date())).png")
        do { try png.write(to: url); return url } catch { return nil }
    }

    // MARK: Loading from SwiftUI drops

    /// Reads dropped items (in their original order) and calls `completion` on the main thread.
    static func load(from providers: [NSItemProvider], completion: @escaping @MainActor ([ShelfItem]) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var results = [Int: ShelfItem]()

        func store(_ item: ShelfItem?, at index: Int) {
            guard let item else { return }
            lock.lock(); results[index] = item; lock.unlock()
        }

        for (index, provider) in providers.enumerated() {
            group.enter()
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    store(url.map { ShelfItem(content: .file($0)) }, at: index)
                    group.leave()
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    let file = (image as? NSImage).flatMap { saveImage($0) }
                    store(file.map { ShelfItem(content: .file($0)) }, at: index)
                    group.leave()
                }
            } else if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    store(url.map { $0.isFileURL ? ShelfItem(content: .file($0)) : ShelfItem(content: .link($0)) }, at: index)
                    group.leave()
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    store(text.map { ShelfItem(content: .text($0)) }, at: index)
                    group.leave()
                }
            } else {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let items = results.keys.sorted().compactMap { results[$0] }
            MainActor.assumeIsolated { completion(items) }
        }
    }
}
