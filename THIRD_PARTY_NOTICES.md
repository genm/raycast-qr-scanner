# Third-Party Dependencies and Assets

The project source is licensed under MIT. Third-party dependencies retain their own licenses and are not relicensed by this project.

## Dependency inventory

- JavaScript and TypeScript dependency versions and declared license metadata are authoritative in `package-lock.json`.
- Swift dependency versions and revisions are authoritative in `swift/Package.resolved`.
- `swift-syntax` is distributed under Apache-2.0 at the pinned revision.
- Raycast's `extensions-swift-tools` is an official build-time bridge pinned in `swift/Package.resolved`. Its upstream repository did not declare a license when this notice was last reviewed on 2026-08-27. It is not vendored here. Maintainers must re-check its terms before distributing generated native artifacts outside the Raycast extension workflow.
- `jsQR` is distributed under Apache-2.0 and performs local QR decoding for the Windows adapter. `pngjs` is distributed under MIT and reads the temporary PNG captures.
- Apple's AVFoundation, AppKit, Core Image, ScreenCaptureKit, and Vision frameworks and the Raycast API are platform dependencies governed separately from this repository's MIT license.

Run `npm audit --omit=dev` for known npm vulnerabilities and inspect lockfile license metadata when dependencies change. Automated metadata is evidence, not a legal compatibility conclusion.

The pinned `allowScripts` entries permit esbuild's binary integrity/install check and fsevents' macOS native setup after review of those exact package versions. Re-review the scripts before changing either pin.

## Project assets

`assets/source-icon.svg` is the editable source for `assets/extension-icon.png`. Both are project assets distributed under the MIT License. The project name and icon must not be used to imply endorsement by the maintainer or by Raycast.
