export type ScanSource = "camera" | "screen" | "clipboard";

export type NativeScanResult = {
  value: string;
  source: ScanSource;
  displayID?: number;
};

export type ResultKind = "url" | "email" | "phone" | "wifi" | "fido" | "text";

export type ClassifiedScanResult = NativeScanResult & {
  kind: ResultKind;
  title: string;
  openTarget?: string;
  wifi?: WifiPayload;
};

export type WifiPayload = {
  authentication?: string;
  ssid?: string;
  password?: string;
  hidden?: boolean;
};

const OPENABLE_SCHEMES = new Set(["http:", "https:", "mailto:", "tel:"]);
const FIDO_DIGIT_CHUNK_LENGTH = 17;
const FIDO_FULL_CHUNK_MAX_VALUE = (1n << 56n) - 1n;
const FIDO_TRAILING_CHUNK_MAX_VALUES = new Map<number, bigint>([
  [0, 0n],
  [3, (1n << 8n) - 1n],
  [5, (1n << 16n) - 1n],
  [8, (1n << 24n) - 1n],
  [10, (1n << 32n) - 1n],
  [13, (1n << 40n) - 1n],
  [15, (1n << 48n) - 1n],
]);

export function classifyScanResult(result: NativeScanResult): ClassifiedScanResult {
  const wifi = parseWifiPayload(result.value);
  if (wifi) {
    return {
      ...result,
      kind: "wifi",
      title: wifi.ssid ? `Wi-Fi: ${wifi.ssid}` : "Wi-Fi Network",
      wifi,
    };
  }

  if (isFidoHybridURI(result.value)) {
    return { ...result, kind: "fido", title: "FIDO Authentication" };
  }

  try {
    const url = new URL(result.value);
    if (OPENABLE_SCHEMES.has(url.protocol)) {
      const kind: ResultKind = url.protocol === "mailto:" ? "email" : url.protocol === "tel:" ? "phone" : "url";
      return { ...result, kind, title: titleForURL(url, kind), openTarget: result.value };
    }
  } catch {
    // A QR payload can be arbitrary text; an invalid URL is a valid text result.
  }

  return { ...result, kind: "text", title: result.value };
}

export function isFidoHybridURI(value: string): boolean {
  const match = /^fido:\/([0-9]+)$/i.exec(value);
  if (!match) return false;

  const encoded = match[1];
  const trailingLength = encoded.length % FIDO_DIGIT_CHUNK_LENGTH;
  const trailingMaxValue = FIDO_TRAILING_CHUNK_MAX_VALUES.get(trailingLength);
  if (trailingMaxValue === undefined) return false;

  const completeLength = encoded.length - trailingLength;
  for (let index = 0; index < completeLength; index += FIDO_DIGIT_CHUNK_LENGTH) {
    if (BigInt(encoded.slice(index, index + FIDO_DIGIT_CHUNK_LENGTH)) > FIDO_FULL_CHUNK_MAX_VALUE) {
      return false;
    }
  }

  // CTAP assigns a fixed decimal width to each possible trailing byte count.
  return trailingLength === 0 || BigInt(encoded.slice(completeLength)) <= trailingMaxValue;
}

export function deduplicateScanResults(results: NativeScanResult[]): NativeScanResult[] {
  const seen = new Set<string>();
  return results.filter((result) => {
    if (seen.has(result.value)) return false;
    seen.add(result.value);
    return true;
  });
}

export function parseWifiPayload(value: string): WifiPayload | undefined {
  if (!value.startsWith("WIFI:")) return undefined;

  const fields = splitEscaped(value.slice(5), ";");
  const parsed: WifiPayload = {};
  for (const field of fields) {
    const separator = findUnescaped(field, ":");
    if (separator < 0) continue;
    const key = field.slice(0, separator);
    const fieldValue = unescapeWifiValue(field.slice(separator + 1));
    if (key === "T") parsed.authentication = fieldValue;
    if (key === "S") parsed.ssid = fieldValue;
    if (key === "P") parsed.password = fieldValue;
    if (key === "H") parsed.hidden = fieldValue.toLowerCase() === "true";
  }

  return parsed;
}

function titleForURL(url: URL, kind: ResultKind): string {
  if (kind === "email") return decodeURIComponent(url.pathname);
  if (kind === "phone") return decodeURIComponent(url.pathname);
  return url.hostname || url.toString();
}

function splitEscaped(value: string, separator: string): string[] {
  const fields: string[] = [];
  let current = "";
  let escaped = false;
  for (const character of value) {
    if (escaped) {
      current += `\\${character}`;
      escaped = false;
    } else if (character === "\\") {
      escaped = true;
    } else if (character === separator) {
      fields.push(current);
      current = "";
    } else {
      current += character;
    }
  }
  fields.push(current);
  return fields;
}

function findUnescaped(value: string, separator: string): number {
  let escaped = false;
  for (let index = 0; index < value.length; index += 1) {
    const character = value[index];
    if (escaped) {
      escaped = false;
    } else if (character === "\\") {
      escaped = true;
    } else if (character === separator) {
      return index;
    }
  }
  return -1;
}

function unescapeWifiValue(value: string): string {
  return value.replace(/\\([\\;,:"])/g, "$1");
}
