# Design QA

- Source visual truth: `Assets/AppIcon.png`
- Implementation: `/Applications/Codex Usage.app`, inspected in Finder list view and Quick Look through Computer Use
- Note: this record was captured before the product was renamed to Codex Usage; the icon findings still apply, and the bundle has since been renamed so Finder shows `Codex Usage`.
- Viewport/state: macOS Applications folder and Quick Look, light appearance, Retina display
- Source dimensions: 1254 × 1254 px; packaged icon: multi-resolution ICNS up to 1024 × 1024 px; Finder rendering uses the system-selected Retina representation

## Evidence

Finder displayed the new icon beside the app name, and Quick Look rendered the large icon with clean rounded edges, transparent corners, readable knot geometry, and the blue balance indicator. A focused comparison was used because the requested visual change was limited to application identity; the menu-bar UI and copy were unchanged.

## Required fidelity surfaces

- Typography and copy: Finder shows `Codex Usage`, from the bundle's own filename; `CFBundleName`/`CFBundleDisplayName` match it.
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

`script/qa.sh` passed the release build, parser/timeout self-check, bundle metadata, ICNS presence, code-signature integrity, process launch, and live Codex usage refresh. Locally built artifacts are ad-hoc signed; Developer ID signing and notarization are release gates, not visual defects. Release builds are universal (arm64 + x86_64).

final result: passed
