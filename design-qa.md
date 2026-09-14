# Design QA

- Source visual truth: `Assets/AppIcon.png`
- Implementation: `/Applications/Codex Balance.app`, inspected in Finder list view and Quick Look through Computer Use
- Viewport/state: macOS Applications folder and Quick Look, light appearance, Retina display
- Source dimensions: 1254 × 1254 px; packaged icon: multi-resolution ICNS up to 1024 × 1024 px; Finder rendering uses the system-selected Retina representation

## Evidence

Finder displayed the new icon beside `Codex Balance`, and Quick Look rendered the large icon with clean rounded edges, transparent corners, readable knot geometry, and the blue balance indicator. A focused comparison was used because the requested visual change was limited to application identity; the menu-bar UI and copy were unchanged.

## Required fidelity surfaces

- Typography and copy: Finder shows `Codex Balance`; bundle display name matches.
- Spacing and layout: icon uses the standard macOS rounded-square silhouette and optical padding.
- Colors and tokens: charcoal, off-white, and blue remain legible in Finder's light appearance.
- Image quality: ICNS contains the standard 16–1024 px representations; no missing-icon placeholder or visible transparency halo.
- Content: no embedded text or third-party trademark.

## Findings

No actionable P0, P1, or P2 visual issues found.

## Comparison history

- Pass 1: Finder showed no application icon because the bundle lacked an icon resource and `CFBundleIconFile`.
- Fix: added an original 1024px source, generated a complete ICNS, bundled it under `Contents/Resources`, and added icon/display-name metadata.
- Pass 2: Finder list view and Quick Look both displayed the packaged icon correctly.

## Automated QA

`script/qa.sh` passed the release build, parser/timeout self-check, bundle metadata, ICNS presence, code-signature integrity, process launch, and live Codex usage refresh. The current artifact is ad-hoc signed and arm64-only; Developer ID notarization and Universal 2 compilation are release gates, not visual defects.

final result: passed
