import { describe, expect, it, vi } from "vitest";

import { singleFlight } from "./single-flight";

describe("singleFlight", () => {
  it("shares one operation between concurrent callers and starts a new one after completion", async () => {
    let resolveFirst: ((value: string) => void) | undefined;
    const start = vi
      .fn<() => Promise<string>>()
      .mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolveFirst = resolve;
          }),
      )
      .mockResolvedValueOnce("second");
    const run = singleFlight(start);

    const first = run();
    const concurrent = run();

    expect(concurrent).toBe(first);
    expect(start).toHaveBeenCalledTimes(1);

    resolveFirst?.("first");
    await expect(first).resolves.toBe("first");
    await expect(run()).resolves.toBe("second");
    expect(start).toHaveBeenCalledTimes(2);
  });

  it("allows retry after a failed operation", async () => {
    const start = vi.fn<() => Promise<string>>().mockRejectedValueOnce(new Error("failed")).mockResolvedValueOnce("ok");
    const run = singleFlight(start);

    await expect(run()).rejects.toThrow("failed");
    await expect(run()).resolves.toBe("ok");
    expect(start).toHaveBeenCalledTimes(2);
  });
});
