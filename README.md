<div align="center">
  <img src="docs/assets/ghostmark-icon.svg" width="112" height="112" alt="GhostMark icon">
  <h1>GhostMark</h1>
  <p>Mark up an image, then send it to your AI agent in Claude Code.</p>
</div>

## Install

Download the latest notarized `GhostMark.pkg` from the [download page](https://alan890104.github.io/GhostMark/) or GitHub Releases, open the installer, and grant Accessibility access once.

Then paste an image with `Ctrl+V` or `⌘V` while Claude Code is active. GhostMark focuses the editor immediately; choose **Send to Claude Code** or press Return to put the marked-up image back in the prompt.

## Features

- Works across Terminal, Ghostty, iTerm2, Warp, kitty, WezTerm, and embedded IDE terminals
- Pen, highlighter, eraser, colors, line width, undo, and redo
- English and Traditional Chinese, selected automatically from macOS language preferences
- Local-only image processing
- Native SwiftUI and AppKit; no third-party runtime dependencies

## Build

Requirements: macOS 14+, Xcode 16+, and Swift 6.

```sh
swift test
./Scripts/generate-icon.sh
./Scripts/build-app.sh
open GhostMark.app
```

Development builds are ad hoc signed with the separate `com.ghostmark.GhostMark.dev` bundle identifier. Public releases keep the stable `com.ghostmark.GhostMark` identity and are built as Universal binaries, signed with Developer ID, hardened, notarized, and stapled by `Scripts/release.sh`.

## Release

```sh
./Scripts/release.sh v0.2.0
```

The release script requires Developer ID Application and Developer ID Installer identities plus a `notarytool` Keychain profile. It builds a Universal app, creates a signed installer, notarizes and staples the package, validates it with Gatekeeper, then pushes the version tag and release assets. The GitHub Pages download button always targets `releases/latest/download/GhostMark.pkg`, so it automatically follows the newest release.

## Privacy

GhostMark has no analytics, telemetry, accounts, or uploads. See [PRIVACY.md](PRIVACY.md).

## License

MIT
