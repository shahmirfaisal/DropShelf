import AppKit
import SwiftUI
import QuickLookThumbnailing

/// Finder-style previews for files (images, PDFs, videos, documents).
@MainActor
enum ThumbnailCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func cachedImage(for item: ShelfItem) -> NSImage? {
        guard let url = item.fileURL else { return nil }
        return cache.object(forKey: url.path as NSString)
    }

    static func thumbnail(for item: ShelfItem) async -> NSImage? {
        guard let url = item.fileURL else { return nil }
        if let cached = cache.object(forKey: url.path as NSString) { return cached }
        let request = QLThumbnailGenerator.Request(fileAt: url,
                                                   size: CGSize(width: 240, height: 240),
                                                   scale: 2,
                                                   representationTypes: .thumbnail)
        guard let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        cache.setObject(rep.nsImage, forKey: url.path as NSString)
        return rep.nsImage
    }
}

struct ItemThumbnail: View {
    let item: ShelfItem
    var size: CGFloat
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.08))
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            } else {
                switch item.content {
                case .text:
                    Image(systemName: "text.alignleft")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.secondary)
                        .frame(width: size * 0.8, height: size * 0.9)
                        .background(.background, in: RoundedRectangle(cornerRadius: 6))
                case .link:
                    Image(systemName: "link")
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: size * 0.85, height: size * 0.85)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                case .file:
                    Image(nsImage: item.icon).resizable().aspectRatio(contentMode: .fit)
                }
            }
        }
        .frame(width: size, height: size)
        .task(id: item.id) { image = await ThumbnailCache.thumbnail(for: item) }
    }
}
