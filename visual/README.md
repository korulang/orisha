# ./visual — the matter of this repo's face

Forged per-repo, committed here so a `git clone` brings the whole face.
This is the MATTER; `../visual-identity.json` is the MANIFEST.

The manifest + the convention travel with the ADD methodology. The matter
does NOT — it is forged for THIS repo and never propagates to another.

Expected assets (drop them here, then point the manifest at them):

THE BACKDROP — `background` in the manifest

- `background.png`       — the albedo (the picture)
- `background_depth.png` — the depth map (drives the parallax offset)

The albedo + depth pair is the same parallax pattern the studio HUD renders
(picture + depth webp, offset by depth in the shader). A consumer with no
shader renders the albedo flat and leaves the depth alone — the still half of
the pair is honest; faking the motion is not.

THE MARK — `avatar` in the manifest

- `mark.svg`             — the mark, authored `fill: currentColor` so ONE asset
                           tints to the repo's accent, or white, or dark-on-light
- `avatar.svg`           — the mark on the repo's own ground, for consumers that
                           cannot supply one (an OS dock, a favicon)
- `avatar-<n>.png`       — the tile rasterised, for consumers with no SVG at all

`avatar` is an OBJECT once forged, and it declares a `min` size: below it a
detailed mark stops being an identity and becomes a smudge, so consumers fall
back to `glyph`. See koru for the reference implementation.

Until art is forged, `background` and `avatar` stay null in the manifest — an
honest stub, not a broken pointer. A consumer must treat a manifest pointing at
a file that isn't there as UNFORGED, not render a broken image.
