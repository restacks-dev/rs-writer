# Release artwork

`app-icon-master.png` is the original generated source artwork; `packaging/icon-master.png` is the normalized 1024px build master, generated with the built-in ImageGen tool on 2026-09-19. Run `swift scripts/make-icon.swift` from the repository root to regenerate every macOS icon size with native AppKit interpolation and preserved transparency.

Final prompt (built-in ImageGen, style transfer with the earlier icon, the user's Re:stacks label and Dock screenshot as references): "Flatten the RS Writer paper-and-pen icon into simple vector-style geometry. Warm ivory macOS tile, terracotta page with peach folded corner and three ivory lines, coral fountain pen with nearly black nib slit. Cream negative space separates pen and page. No gloss, bevel, metal, texture, realistic paper or 3D volume. Transparent exterior, generous padding, crisp silhouette; no lettering, watermark or copied app logos."

The matching installer background is generated with `swift scripts/make-dmg-background.swift`. The 720 × 360 layout reserves icon centers at (180,230) and (540,230) in Finder coordinates. Use `packaging/dmg-background.png`, 96px Finder icons and a 720 × 392 window including the title bar. The app and Applications folder are real Finder items, with the directional arrow as the installation cue.

Brand palette supplied by the user: warm cream, near-black, terracotta, coral and peach. Both the final icon and DMG use these colors. Per the user's final revision, the DMG contains no tagline, numbered instructions, HTML document or system-requirements footer.
