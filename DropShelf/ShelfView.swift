import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShelfView: View {
    @ObservedObject var shelf: Shelf
    let controller: ShelfController
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            Group {
                if shelf.items.isEmpty {
                    emptyState
                } else if shelf.isExpanded {
                    expandedList
                } else {
                    collapsedStack
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(shelf.isDropTargeted ? Color.accentColor : Color.primary.opacity(0.12),
                              lineWidth: shelf.isDropTargeted ? 3 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeOut(duration: 0.15), value: shelf.isDropTargeted)
        .onDrop(of: ShelfDropDelegate.types, delegate: ShelfDropDelegate(shelf: shelf))
    }

    // MARK: Header — drag here to move the shelf

    private var header: some View {
        HStack(spacing: 6) {
            Button { ShelfManager.shared.close(controller) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close shelf")

            Text(countText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

            Button { shelf.isExpanded.toggle() } label: {
                Image(systemName: shelf.isExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(shelf.items.isEmpty)
            .opacity(shelf.items.isEmpty ? 0.3 : 1)
            .help(shelf.isExpanded ? "Collapse" : "Show all items")
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(WindowDragArea())
    }

    private var countText: String {
        switch shelf.items.count {
        case 0: "Shelf"
        case 1: "1 item"
        default: "\(shelf.items.count) items"
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 30, weight: .light))
            Text("Drop here")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(shelf.isDropTargeted ? Color.accentColor : .secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(shelf.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.5))
        )
        .padding(12)
    }

    // MARK: Collapsed — drag the stack to take everything

    private var collapsedStack: some View {
        VStack(spacing: 10) {
            ZStack {
                let preview = Array(shelf.items.suffix(3))
                ForEach(Array(preview.enumerated()), id: \.element.id) { index, item in
                    let fromTop = preview.count - 1 - index
                    ItemThumbnail(item: item, size: 96)
                        .rotationEffect(.degrees(Double(fromTop) * (index.isMultiple(of: 2) ? -7 : 7)))
                        .offset(x: CGFloat(fromTop) * 4, y: CGFloat(fromTop) * -4)
                }
            }
            .frame(height: 112)

            Text(shelf.items.count == 1 ? shelf.items[0].title : "Drag to move all \(shelf.items.count)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay(
            DragSource(shelfID: shelf.id,
                       items: { shelf.items },
                       onClick: { shelf.isExpanded = true },
                       onDragEnded: handleDragEnded)
        )
        .help("Drag to drop everything somewhere · Click to see items")
    }

    // MARK: Expanded — drag single items, or all from the top bar

    private var expandedList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                Text("Drag all \(shelf.items.count) items")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay(DragSource(shelfID: shelf.id, items: { shelf.items }, onDragEnded: handleDragEnded))
            .padding(10)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(shelf.items) { item in
                        ItemRow(item: item, shelf: shelf, onDragEnded: handleDragEnded)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
        }
    }

    private func handleDragEnded(_ ids: [UUID], _ succeeded: Bool) {
        guard succeeded, settings.removeAfterDragOut else { return }
        shelf.remove(ids)
    }
}

struct ItemRow: View {
    let item: ShelfItem
    @ObservedObject var shelf: Shelf
    let onDragEnded: ([UUID], Bool) -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                ItemThumbnail(item: item, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .overlay(DragSource(shelfID: shelf.id, items: { [item] }, onDragEnded: onDragEnded))

            Button { shelf.remove([item.id]) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Remove from shelf")
        }
        .padding(6)
        .background(hovering ? Color.primary.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
        .contextMenu {
            if let url = item.fileURL {
                Button("Open") { NSWorkspace.shared.open(url) }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            if case .link(let url) = item.content {
                Button("Open Link") { NSWorkspace.shared.open(url) }
            }
            Divider()
            Button("Remove from Shelf") { shelf.remove([item.id]) }
        }
    }
}

/// Accepts files, images, links and text dropped anywhere on a shelf.
struct ShelfDropDelegate: DropDelegate {
    static let types: [UTType] = [.fileURL, .url, .image, .plainText]
    let shelf: Shelf

    private var isFromThisShelf: Bool { DragSourceNSView.activeShelfID == shelf.id }

    func validateDrop(info: DropInfo) -> Bool {
        return !isFromThisShelf && info.hasItemsConforming(to: Self.types)
    }

    func dropEntered(info: DropInfo) {
        if validateDrop(info: info) { shelf.isDropTargeted = true }
    }

    func dropExited(info: DropInfo) {
        shelf.isDropTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: validateDrop(info: info) ? .copy : .forbidden)
    }

    func performDrop(info: DropInfo) -> Bool {
        shelf.isDropTargeted = false
        // Read the system drag pasteboard directly: it has the real file references
        // (item providers can turn a dropped text file into its contents).
        let direct = ShelfItem.items(from: NSPasteboard(name: .drag))
        if !direct.isEmpty {
            shelf.add(direct)
            return true
        }
        // Fallback for drags that only offer item providers
        let providers = info.itemProviders(for: Self.types)
        guard !providers.isEmpty else { return false }
        shelf.closesIfLeftEmpty = false   // something is on its way
        ShelfItem.load(from: providers) { items in
            shelf.add(items)
        }
        return true
    }
}
