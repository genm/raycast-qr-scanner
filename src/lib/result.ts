export type ScanSource = "camera" | "screen" | "clipboard";

export type NativeScanResult = {
  value: string;
  source: ScanSource;
  displayID?: number;
};

export type ResultKind = "url" | "email" | "phone" | "wifi" | "text";

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

  if (!parsed.ssid && !parsed.password && !parsed.authentication) {
    return undefined;
  }

  return parsed;
}

function safeDecodeURIComponent(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

function titleForURL(url: URL, kind: ResultKind): string {
  if (kind === "email") return safeDecodeURIComponent(url.pathname);
  if (kind === "phone") return safeDecodeURIComponent(url.pathname);
  return url.host || url.hostname || url.toString();
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
