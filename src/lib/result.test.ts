import { describe, expect, it } from "vitest";

import { classifyScanResult, deduplicateScanResults, parseWifiPayload } from "./result";

describe("classifyScanResult", () => {
  it.each([
    ["https://example.test/path", "url"],
    ["mailto:user@example.test", "email"],
    ["tel:+12025550123", "phone"],
    ["WIFI:T:WPA;S:Office;P:correct-horse;;", "wifi"],
    ["ordinary text", "text"],
  ] as const)("classifies %s as %s", (value, expectedKind) => {
    expect(classifyScanResult({ value, source: "screen" }).kind).toBe(expectedKind);
  });

  it("does not treat unsupported schemes as openable URLs", () => {
    const result = classifyScanResult({ value: "javascript:alert(1)", source: "screen" });

    expect(result.kind).toBe("text");
    expect(result.openTarget).toBeUndefined();
  });

  it("preserves ports in URL titles", () => {
    const result = classifyScanResult({ value: "http://localhost:3000/test", source: "screen" });

    expect(result.kind).toBe("url");
    expect(result.title).toBe("localhost:3000");
  });

  it("safely handles malformed percent encoding in mailto URLs", () => {
    const result = classifyScanResult({ value: "mailto:user%99@example.test", source: "screen" });

    expect(result.kind).toBe("email");
    expect(result.title).toBe("user%99@example.test");
    expect(result.openTarget).toBe("mailto:user%99@example.test");
  });
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

  it("returns undefined when no SSID, password, or authentication is present", () => {
    expect(parseWifiPayload("WIFI:")).toBeUndefined();
    expect(parseWifiPayload("WIFI:;")).toBeUndefined();
    expect(parseWifiPayload("WIFI:H:true;")).toBeUndefined();
    expect(parseWifiPayload("WIFI: not a wifi payload")).toBeUndefined();
  });
});
