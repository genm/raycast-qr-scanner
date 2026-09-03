import jsQR, { QRCode } from "jsqr";
import { PNG } from "pngjs";

const MAX_DECODED_CODES = 64;

export async function decodeQRImage(pngData: Buffer): Promise<string[]> {
  const image = PNG.sync.read(pngData);
  const pixels = Uint8ClampedArray.from(image.data);
  const values: string[] = [];

  let iterations = 0;
  for (
    let code = jsQR(pixels, image.width, image.height);
    code && iterations < MAX_DECODED_CODES;
    iterations += 1, code = jsQR(pixels, image.width, image.height)
  ) {
    if (!values.includes(code.data)) values.push(code.data);
    eraseDetectedCode(pixels, image.width, image.height, code);
  }

  return values;
}

function eraseDetectedCode(pixels: Uint8ClampedArray, width: number, height: number, code: QRCode): void {
  const points = [
    code.location.topLeftCorner,
    code.location.topRightCorner,
    code.location.bottomLeftCorner,
    code.location.bottomRightCorner,
  ];
  const minX = Math.max(0, Math.floor(Math.min(...points.map((point) => point.x))));
  const maxX = Math.min(width - 1, Math.ceil(Math.max(...points.map((point) => point.x))));
  const minY = Math.max(0, Math.floor(Math.min(...points.map((point) => point.y))));
  const maxY = Math.min(height - 1, Math.ceil(Math.max(...points.map((point) => point.y))));

  if (minX > maxX || minY > maxY) return;

  // Removing a decoded region lets jsQR find additional codes without imposing a result-count limit.
  for (let y = minY; y <= maxY; y += 1) {
    for (let x = minX; x <= maxX; x += 1) {
      const offset = (y * width + x) * 4;
      pixels[offset] = 255;
      pixels[offset + 1] = 255;
      pixels[offset + 2] = 255;
      pixels[offset + 3] = 255;
    }
  }
}
