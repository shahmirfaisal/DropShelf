# DropShelf

A free, open-source drag-and-drop shelf for macOS. Shake your cursor while dragging something and a small shelf appears. Drop files on it, go wherever you need to, then drag them back out.

## Features

- **Shake to open:** start dragging a file, then quickly move the cursor left and right — a shelf appears right under it
- **Collect anything:** files, folders, images (even straight from a web page), links and text
- **Drag everything out at once** from the stack, or **expand** the shelf to drag out single items
- **As many shelves as you like** — each shake opens a new one, so you can keep groups separate
- **Move items between shelves** by dragging from one to another
- Finder-style previews for images, PDFs, videos and documents
- Shelves close by themselves when they're empty
- Lives in the menu bar — **New Shelf** (⌘N in the menu) if you'd rather not shake

## How to use

1. Start dragging one or more files in Finder (or an image in your browser).
2. Without letting go, shake the cursor left and right a few times. A shelf appears.
3. Drop the files on it. You can add more at any time.
4. Later, drag the stack to where you want everything — another folder, an email, a chat, an upload box.
   Click the stack (or the ⤢ button) to see every item and drag out just the ones you need.

Tips:
- Drag a shelf by its top bar to move it.
- Dragging files from a shelf into Finder **moves** them, like any normal drag. Hold **⌥ Option** while dropping to copy instead.
- Right-click an item in an expanded shelf to open it or show it in Finder.
- Change shake sensitivity in **Settings** (menu bar icon → Settings…).

## Install

Requires **macOS 14.6 or later** (Apple Silicon or Intel).

1. Download the latest `DropShelf-x.x.dmg` from [Releases](../../releases).
2. Open it and drag **DropShelf** into **Applications**.
3. Open DropShelf. macOS will say *"Apple could not verify DropShelf is free of malware"* — this is expected, because DropShelf isn't distributed through Apple's paid developer program. Click **Done**.
4. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to the DropShelf message. Confirm with your password. You only do this once.

   If you see the same message when opening the `.dmg`, use **Open Anyway** for it in the same way.

   <details><summary>Prefer Terminal?</summary>

   After dragging DropShelf into Applications, this removes the download flag so it opens normally:

   ```bash
   xattr -dr com.apple.quarantine /Applications/DropShelf.app
   ```
   </details>

The tray icon appears in your menu bar. No extra permissions are needed.

## Privacy

DropShelf makes no network connections. Shelves only hold references to your files — nothing is copied or uploaded. Images dropped straight from a web page are saved in `~/Library/Caches/DropShelf/` so they can be dragged out again.

## Build from source

Requires Xcode 16 or later.

```bash
git clone <this repo>
cd DropShelf
open DropShelf.xcodeproj
```

Then press ⌘R. Builds are signed with a self-signed certificate named "ClipVault Developer"; create your own code-signing certificate and change `CODE_SIGN_IDENTITY` in the project (and `SIGN_ID` in `scripts/release.sh`). To build a DMG:

```bash
./scripts/release.sh
```

## Related

[ClipVault](https://github.com/shahmirfaisal/ClipVault) — a free clipboard manager for macOS.

## License

MIT — see [LICENSE](LICENSE).
