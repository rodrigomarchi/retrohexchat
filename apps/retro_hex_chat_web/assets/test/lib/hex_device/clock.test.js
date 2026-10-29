import { describe, expect, it } from "vitest";
import { formatElapsed, formatLength } from "../../../js/lib/hex_device/clock.js";

describe("formatElapsed", () => {
  it("shows minutes and seconds, and hours past an hour", () => {
    expect(formatElapsed(0)).toBe("0:00");
    expect(formatElapsed(65_000)).toBe("1:05");
    expect(formatElapsed(3_725_000)).toBe("1:02:05");
  });
});

describe("formatLength", () => {
  it("shows a known length, and dashes for a stream or a file still loading", () => {
    expect(formatLength(42.4)).toBe("0:42");
    expect(formatLength(Number.POSITIVE_INFINITY)).toBe("--:--");
    expect(formatLength(Number.NaN)).toBe("--:--");
    expect(formatLength(0)).toBe("--:--");
  });
});
