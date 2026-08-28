import { PNG } from "pngjs";
import QRCode from "qrcode";
import { describe, expect, it } from "vitest";

import { decodeQRImage } from "./qr-image";

describe("decodeQRImage", () => {
  it("decodes every QR code in one image", async () => {
    const first = PNG.sync.read(await QRCode.toBuffer("https://example.test/first", { margin: 4, width: 240 }));
    const second = PNG.sync.read(await QRCode.toBuffer("WIFI:T:WPA;S:Example;P:secret;;", { margin: 4, width: 240 }));
    const combined = new PNG({ width: 520, height: 260, fill: true });
    PNG.bitblt(first, combined, 0, 0, first.width, first.height, 10, 10);
    PNG.bitblt(second, combined, 0, 0, second.width, second.height, 270, 10);

    await expect(decodeQRImage(PNG.sync.write(combined))).resolves.toEqual(
      expect.arrayContaining(["https://example.test/first", "WIFI:T:WPA;S:Example;P:secret;;"]),
    );
  });

  it("returns an empty result for an image without a QR code", async () => {
    const image = new PNG({ width: 200, height: 200, fill: true });

    await expect(decodeQRImage(PNG.sync.write(image))).resolves.toEqual([]);
  });
});
