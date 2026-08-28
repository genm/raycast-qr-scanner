# Troubleshooting

## Camera panel does not appear

Open **System Settings > Privacy & Security > Camera** and allow Raycast. Run the command again. If macOS requested a restart, quit and reopen Raycast before retesting.

If no camera is installed or available, Raycast reports that no available camera was found; changing Camera permission cannot create missing hardware. A managed or restricted Mac can also prevent access even when the user cannot change the privacy toggle.

On Windows, the command opens the registered Windows Camera app instead of a Raycast-owned panel. Confirm Windows Camera is installed and can show a preview on its own. Camera permission is granted to Windows Camera in **Settings > Privacy & security > Camera**. Closing that window before detection intentionally returns a cancellation result to Raycast.

## Camera is active but no QR is detected

- Use an undamaged QR code with adequate contrast and lighting.
- Keep the entire quiet zone visible.
- Try a larger presentation before moving the code farther away.
- Avoid motion blur and severe perspective angles.
- On macOS, confirm the status has changed to `Camera active — looking for QR code…`; the opening message alone does not prove that frames reached Vision.

The CI pipeline covers rotations, mirroring, several apparent distances, multiple QR codes, and QR-free frames. A reproducible live-camera failure should include the OS version, camera model, Raycast version, and privacy-safe diagnostics—not the QR payload or an unredacted camera image.

## Highlight does not surround the QR code

The overlay uses the frozen frame's pixel dimensions, Vision's normalized lower-left coordinates, the panel's `resizeAspectFill` crop, and the destination layer's flipped state. First ensure the running development extension was rebuilt after the latest source change.

When reporting a remaining mismatch, state whether it is horizontal, vertical, mirrored, consistently offset, or scale-dependent. Use a synthetic QR containing a reserved `.test` URL and crop screenshots to the camera panel.

## Camera closes but no result is visible

The camera uses a nonactivating `NSPanel`, and the Raycast bridge explicitly restores Raycast when scanning finishes. It does not rely on macOS's reported frontmost application because Raycast's overlay may not own that state, and normal application activation does not reveal the launcher. The bridge therefore opens the bare `raycast://` application scheme after hiding the camera panel; it does not relaunch the scan command or discard its result state. Stop and restart `npm run dev` after rebuilding so Raycast is not using an older native helper.

Expected behavior is:

1. detect the QR code;
2. show the frozen success frame for one second;
3. close only the camera panel;
4. restore Raycast to the foreground;
5. show the result list in the existing Raycast view.

Scanning never opens a URL automatically. Use the result's action panel to open or copy it.

On Windows, the extension restores Raycast through the bare `raycast://` application scheme after detection or cancellation. It does not terminate Windows Camera; Raycast simply returns to the foreground and leaves app lifecycle control with the user.

## Build reports a Swift package or build-database conflict

Stop `npm run dev` and wait for its `xcodebuild` process to exit before running `npm run build` or `npm run check`. The prebuild guard intentionally fails rather than allowing concurrent debug and release builds to corrupt or lock the shared native build database.

Do not delete build state while another build is active. Confirm the owning process has exited first.

## Privacy-safe camera diagnostics

Stream only the extension's camera lifecycle category:

```sh
log stream --style compact --level info \
  --predicate 'subsystem == "com.genm.qr-scanner" AND category == "camera"'
```

Start the log stream, reproduce once, then stop it. The category records session start, first-frame dimensions and pixel format, detected count, Vision errors, and completion reason. It does not intentionally record QR payloads or image data.

Review the output before sharing it. Remove usernames, paths, unrelated process details, or other personal information. Never attach an unredacted desktop capture, camera frame, Wi-Fi password, clipboard content, or real QR payload.

## Permission-specific errors

On macOS, Raycast presents distinct guidance and actions for Camera and Screen Recording permission denials. Restricted camera access is reported as a policy restriction. On Windows, Windows Camera owns its camera permission UI and screen capture uses built-in desktop APIs. Clipboard scanning does not require either permission. An image without a QR code is different from an empty clipboard and should remain a `No QR Code Found` result rather than a permission error.
