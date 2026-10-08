# Living forest theme

The existing Flutter layouts, wording, icons, dimensions, navigation, state and APIs are retained. The reference mockup supplies the visual treatment; it does not replace the repository's dashboard structure.

The app-level `ForestBackdrop` sits behind the navigator. Transparent scaffold canvases expose an offline, bundled forest scene; existing cards use translucent emerald surfaces and light text. The existing theme toggle switches between golden daylight and a moonlit version of the same scene with a 700 ms crossfade. Night mode includes drifting, pulsing fireflies. Day mode has subtle floating pollen, and both modes have faint drifting mist. These are layered artwork and Flutter particle effects, rather than a real-time 3D scene.

All decorative layers ignore pointer events and semantics. Animation ticks repaint only the atmosphere, rather than rebuilding the app. The controller stops when the app is backgrounded or animations are disabled by the operating system. Reduced-motion mode also disables the background crossfade. Maps and camera/product previews retain their existing content.

## Assets

- `assets/forest/forest_day.webp`
- `assets/forest/forest_night.webp`

The two assets total approximately 0.8 MB, are bundled through pubspec, and require no background network requests. Each decodes at 853 × 1844 pixels. Artwork was generated with the built-in image generation tool, then compressed to WebP.

Day prompt: Create only portrait forest scenery, without UI, text, labels or a phone. A massive ancient trunk at the left edge, canopy overhead, moss and ferns at the bottom, a creek and distant waterfall on the right, distant mountains, golden sunlight and fine mist. Keep the center in soft green shade for readable UI overlays. Cinematic realistic stylized 3D.

Night prompt: Edit the day forest into its night counterpart, preserving the camera, tree shapes, waterfall, creek and mountain placement. Change lighting to moonlit navy and teal with silver moon shafts, deep emerald moss, cool water reflections, and a few tiny warm golden-green fireflies. Keep the center quiet and dark. No UI, text, labels or phone.

## Review

Use the existing light/dark toggle on the app bar or login screen. Check the dashboard, drawer, tracker, community, maps, forms and dialogs in both modes. Verify that scrolling, all existing actions, and foreground/background transitions still work. Device performance should be confirmed on an Android phone before release.
