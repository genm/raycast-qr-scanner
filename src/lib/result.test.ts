import { describe, expect, it } from "vitest";

import { classifyScanResult, deduplicateScanResults, parseWifiPayload } from "./result";

const FIDO_HYBRID_URI =
  "FIDO:/333536986729023101900514898282206507478832499810394616328939171432525164832007214567361368903544184100030234061231042500070214287790524650362650854032130107096654083076";

describe("classifyScanResult", () => {
  it.each([
    ["https://example.test/path", "url"],
    ["mailto:user@example.test", "email"],
    ["tel:+12025550123", "phone"],
    ["WIFI:T:WPA;S:Office;P:correct-horse;;", "wifi"],
    [FIDO_HYBRID_URI, "fido"],
    ["ordinary text", "text"],
  ] as const)("classifies %s as %s", (value, expectedKind) => {
    expect(classifyScanResult({ value, source: "screen" }).kind).toBe(expectedKind);
  });

  it("does not treat unsupported schemes as openable URLs", () => {
    const result = classifyScanResult({ value: "javascript:alert(1)", source: "screen" });

    expect(result.kind).toBe("text");
    expect(result.openTarget).toBeUndefined();
  });

  it("presents a valid FIDO hybrid URI as an explicit passkey request", () => {
    const result = classifyScanResult({ value: FIDO_HYBRID_URI, source: "camera" });

    expect(result).toMatchObject({ kind: "fido", title: "FIDO Authentication", openTarget: FIDO_HYBRID_URI });
    expect(classifyScanResult({ value: FIDO_HYBRID_URI.toLowerCase(), source: "camera" }).kind).toBe("fido");
  });

  it.each(["FIDO://123", "FIDO:/12a3", "FIDO:/", "FIDO:/1", "FIDO:/999", "FIDO:/99999999999999999"])(
    "keeps malformed FIDO content as text: %s",
    (value) => {
      expect(classifyScanResult({ value, source: "screen" }).kind).toBe("text");
    },
  );
});

describe("deduplicateScanResults", () => {
  it("keeps the first occurrence while preserving distinct values", () => {
    const results = deduplicateScanResults([
      { value: "https://example.test", source: "screen", displayID: 1 },
      { value: "https://example.test", source: "screen", displayID: 2 },
      { value: "hello", source: "screen", displayID: 2 },
    ]);

    expect(results).toEqual([
      { value: "https://example.test", source: "screen", displayID: 1 },
      { value: "hello", source: "screen", displayID: 2 },
    ]);
  });
});

describe("parseWifiPayload", () => {
  it("preserves escaped delimiters in SSIDs and passwords", () => {
    expect(parseWifiPayload("WIFI:T:WPA;S:Office\\;Guest;P:p\\:ass\\;word;H:true;;")).toEqual({
      authentication: "WPA",
      ssid: "Office;Guest",
      password: "p:ass;word",
      hidden: true,
    });
  });
});
