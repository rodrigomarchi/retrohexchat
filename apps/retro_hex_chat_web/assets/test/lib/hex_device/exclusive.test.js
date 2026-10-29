import { describe, expect, it, vi } from "vitest";
import { claimSound } from "../../../js/lib/hex_device/exclusive.js";

describe("claimSound", () => {
  it("stops every other device when one starts, never the one that started", () => {
    const first = document.createElement("div");
    const second = document.createElement("div");
    const stopFirst = vi.fn();
    const stopSecond = vi.fn();
    const a = claimSound(window, first, stopFirst);
    const b = claimSound(window, second, stopSecond);

    a.announce();
    expect(stopFirst).not.toHaveBeenCalled();
    expect(stopSecond).toHaveBeenCalledTimes(1);

    b.release();
    a.announce();
    expect(stopSecond).toHaveBeenCalledTimes(1);
    a.release();
  });
});
