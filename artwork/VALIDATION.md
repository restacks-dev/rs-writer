# Artwork validation — 2026-09-19

- User supplied Re:stacks reference; final palette changed to terracotta, coral, cream and near-black.
- Built-in ImageGen applied the brand colors and then flattened the icon in response to the user’s Dock reference: geometric page, simple pen and cream tile.
- Original generated master: square PNG, alpha channel present.
- Build master: packaging/icon-master.png normalized to 1024 × 1024. Native AppKit generator produced all ten required macOS icon slots at their exact pixel sizes.
- Inspected full-size master and 64px icon visually.
- DMG background: native AppKit rendering, 720 × 360 pixels and points. Inspected final cream/terracotta layout visually.
- Finder placement contract: app center (180,230), Applications center (540,230); icon size 96. Avoid adding baked labels under the first two icons because Finder supplies them.
- Local full Xcode build blocked by unaccepted Xcode license. Do not accept terms automatically.
- Swift tests through standalone Command Line Tools were attempted but that toolchain does not include XCTest. The app code was unchanged by this work; run the full tests using Xcode or GitHub CI.
