import { describe, it, expect } from "vitest";

import { Interpolator } from "../../../js/lib/space/interpolation.js";

describe("Interpolator", () => {
  it("reset places a key immediately with no tween", () => {
    const interp = new Interpolator({ duration: 100 });
    interp.reset("k", 3, 4);
    expect(interp.position("k", 0)).toEqual({ x: 3, y: 4 });
    expect(interp.position("k", 1000)).toEqual({ x: 3, y: 4 });
  });

  it("interpolates linearly from the previous tile to the new one over the duration", () => {
    const interp = new Interpolator({ duration: 100 });
    interp.reset("k", 0, 0);
    interp.moveTo("k", 1, 0, 0);

    expect(interp.position("k", 0)).toEqual({ x: 0, y: 0 });
    expect(interp.position("k", 50)).toEqual({ x: 0.5, y: 0 });
    expect(interp.position("k", 100)).toEqual({ x: 1, y: 0 });
  });

  it("clamps past the duration to the target", () => {
    const interp = new Interpolator({ duration: 100 });
    interp.reset("k", 0, 0);
    interp.moveTo("k", 2, 3, 0);
    expect(interp.position("k", 500)).toEqual({ x: 2, y: 3 });
  });

  it("chains moves from the current sampled position", () => {
    const interp = new Interpolator({ duration: 100 });
    interp.reset("k", 0, 0);
    interp.moveTo("k", 1, 0, 0);
    // Retarget mid-tween: new tween starts from where we are now (~0.5).
    interp.moveTo("k", 1, 1, 50);
    expect(interp.position("k", 50)).toEqual({ x: 0.5, y: 0 });
    expect(interp.position("k", 100)).toEqual({ x: 0.75, y: 0.5 });
  });

  it("returns null for an unknown key and forgets a removed one", () => {
    const interp = new Interpolator({ duration: 100 });
    expect(interp.position("ghost", 0)).toBe(null);

    interp.reset("k", 1, 1);
    interp.remove("k");
    expect(interp.position("k", 0)).toBe(null);
  });
});
