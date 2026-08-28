import { closeMainWindow, environment, open } from "@raycast/api";
import { runPowerShellScript } from "@raycast/utils";
import { mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import { join } from "node:path";

import { decodeQRImage } from "./qr-image";
import { NativeScanResult } from "./result";

const CAMERA_SCAN_INTERVAL_MS = 700;

export async function scanWindowsScreen(): Promise<NativeScanResult[]> {
  return withTemporaryDirectory(async (directory) => {
    await closeMainWindow();
    await delay(250);

    try {
      await captureAllDisplays(directory);
      const files = (await readdir(directory)).filter((file) => file.endsWith(".png")).sort(numericFileSort);
      const results = await Promise.all(
        files.map(async (file, index) =>
          (await decodeQRImage(await readFile(join(directory, file)))).map((value) => ({
            value,
            source: "screen" as const,
            displayID: index + 1,
          })),
        ),
      );
      return requireResults(results.flat());
    } finally {
      await revealRaycast();
    }
  });
}

export async function scanWindowsClipboard(): Promise<NativeScanResult[]> {
  return withTemporaryDirectory(async (directory) => {
    const imagePath = join(directory, "clipboard.png");
    await saveClipboardImage(imagePath);
    const values = await decodeQRImage(await readFile(imagePath));
    return requireResults(values.map((value) => ({ value, source: "clipboard" as const })));
  });
}

export async function scanWindowsCamera(): Promise<NativeScanResult[]> {
  return withTemporaryDirectory(async (directory) => {
    const imagePath = join(directory, "camera.png");
    await closeMainWindow();

    try {
      await runPowerShellScript(`
try {
  if (-not (Get-AppxPackage -Name 'Microsoft.WindowsCamera' -ErrorAction SilentlyContinue)) {
    throw 'Windows Camera is not installed for the current user.'
  }
  Start-Process 'microsoft.windows.camera:'
} catch {
  throw ('QRSCANNER_CAMERA_UNAVAILABLE: ' + $_.Exception.Message)
}
`);
      let cameraWasVisible = false;
      while (true) {
        const captured = await captureCameraWindow(imagePath, cameraWasVisible);
        if (!captured) {
          await delay(CAMERA_SCAN_INTERVAL_MS);
          continue;
        }
        cameraWasVisible = true;
        const values = await decodeQRImage(await readFile(imagePath));
        if (values.length > 0) return values.map((value) => ({ value, source: "camera" as const }));
        await delay(CAMERA_SCAN_INTERVAL_MS);
      }
    } finally {
      await revealRaycast();
    }
  });
}

async function captureAllDisplays(outputDirectory: string): Promise<void> {
  const directory = quotePowerShell(outputDirectory);
  await runPowerShellScript(
    `
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$screens = [System.Windows.Forms.Screen]::AllScreens
if ($screens.Count -eq 0) {
  throw 'QRSCANNER_SCREEN_UNAVAILABLE: No visible display was available.'
}

$index = 0
foreach ($screen in $screens) {
  $bitmap = $null
  $graphics = $null
  try {
    $bounds = $screen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
    $path = Join-Path '${directory}' ($index.ToString() + '.png')
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  } catch {
    throw ('QRSCANNER_SCREEN_UNAVAILABLE: ' + $_.Exception.Message)
  } finally {
    if ($graphics) { $graphics.Dispose() }
    if ($bitmap) { $bitmap.Dispose() }
  }
  $index += 1
}
`,
    { timeout: 30_000 },
  );
}

async function captureCameraWindow(outputPath: string, cameraWasVisible: boolean): Promise<boolean> {
  const path = quotePowerShell(outputPath);
  const output = await runPowerShellScript(
    `
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class QRScannerWindowBounds {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr window, out RECT bounds);
}
'@

$camera = Get-Process -Name @('WindowsCamera', 'Camera') -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } |
  Select-Object -First 1
if (-not $camera) {
  if (${cameraWasVisible ? "$true" : "$false"}) {
    throw 'QRSCANNER_CAMERA_CANCELLED: The Windows Camera window was closed.'
  }
  Write-Output 'WAITING'
  exit 0
}

$bounds = New-Object QRScannerWindowBounds+RECT
if (-not [QRScannerWindowBounds]::GetWindowRect($camera.MainWindowHandle, [ref]$bounds)) {
  throw 'QRSCANNER_CAMERA_CANCELLED: The Windows Camera window was closed.'
}

$bitmap = $null
$graphics = $null
try {
  $width = $bounds.Right - $bounds.Left
  $height = $bounds.Bottom - $bounds.Top
  $bitmap = New-Object System.Drawing.Bitmap($width, $height)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.CopyFromScreen($bounds.Left, $bounds.Top, 0, 0, (New-Object System.Drawing.Size($width, $height)))
  $bitmap.Save('${path}', [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Output 'CAPTURED'
} catch {
  throw ('QRSCANNER_CAMERA_UNAVAILABLE: ' + $_.Exception.Message)
} finally {
  if ($graphics) { $graphics.Dispose() }
  if ($bitmap) { $bitmap.Dispose() }
}
`,
    { timeout: 15_000 },
  );
  return output.trim().endsWith("CAPTURED");
}

async function saveClipboardImage(outputPath: string): Promise<void> {
  const path = quotePowerShell(outputPath);
  await runPowerShellScript(`
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not [System.Windows.Forms.Clipboard]::ContainsImage()) {
  throw 'QRSCANNER_CLIPBOARD_NO_IMAGE: The clipboard does not contain an image.'
}

$image = $null
try {
  $image = [System.Windows.Forms.Clipboard]::GetImage()
  $image.Save('${path}', [System.Drawing.Imaging.ImageFormat]::Png)
} catch {
  throw ('QRSCANNER_IMAGE_CONVERSION_FAILED: ' + $_.Exception.Message)
} finally {
  if ($image) { $image.Dispose() }
}
`);
}

async function withTemporaryDirectory<T>(operation: (directory: string) => Promise<T>): Promise<T> {
  const directory = await mkdtemp(join(environment.supportPath, "scan-"));
  try {
    return await operation(directory);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}

function requireResults(results: NativeScanResult[]): NativeScanResult[] {
  if (results.length === 0) throw new Error("QRSCANNER_NO_QR_CODE: No QR code was found.");
  return results;
}

function quotePowerShell(value: string): string {
  return value.replaceAll("'", "''");
}

function numericFileSort(left: string, right: string): number {
  return Number.parseInt(left, 10) - Number.parseInt(right, 10);
}

async function revealRaycast(): Promise<void> {
  // Showing Raycast again is a best-effort UI restoration and must not replace a scan result or scan error.
  await open("raycast://").catch(() => undefined);
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
