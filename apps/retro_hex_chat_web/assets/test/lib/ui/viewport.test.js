import { describe, expect, it } from "vitest";

import {
  KEYBOARD_INSET_THRESHOLD,
  MOBILE_BREAKPOINT,
  computeViewport,
  viewportChanged,
  viewportCssVars,
  viewportPayload,
} from "../../../js/lib/ui/viewport.js";

const base = {
  innerWidth: 1024,
  innerHeight: 768,
  visualViewport: null,
  editableFocused: false,
};

describe("computeViewport", () => {
  it("falls back to inner dimensions when there is no visual viewport", () => {
    const s = computeViewport(base);
    expect(s.visualWidth).toBe(1024);
    expect(s.visualHeight).toBe(768);
    expect(s.keyboardInset).toBe(0);
  });

  it("rounds fractional measurements", () => {
    const s = computeViewport({ ...base, innerWidth: 1024.6, innerHeight: 767.4 });
    expect(s.width).toBe(1025);
    expect(s.height).toBe(767);
  });

  it("flags mobile below the breakpoint", () => {
    expect(computeViewport({ ...base, innerWidth: MOBILE_BREAKPOINT - 1 }).mobile).toBe(true);
    expect(computeViewport({ ...base, innerWidth: MOBILE_BREAKPOINT }).mobile).toBe(false);
  });

  it("computes the keyboard inset from the visual viewport", () => {
    const s = computeViewport({
      ...base,
      innerWidth: 400,
      innerHeight: 800,
      visualViewport: { width: 400, height: 500, offsetTop: 0 },
      editableFocused: true,
    });
    expect(s.keyboardInset).toBe(300);
    expect(s.keyboardOpen).toBe(true);
  });

  it("does not open the keyboard when nothing is focused", () => {
    const s = computeViewport({
      ...base,
      innerWidth: 400,
      innerHeight: 800,
      visualViewport: { width: 400, height: 500, offsetTop: 0 },
      editableFocused: false,
    });
    expect(s.keyboardOpen).toBe(false);
  });

  it("does not open the keyboard for a small inset", () => {
    const s = computeViewport({
      ...base,
      innerWidth: 400,
      innerHeight: 800,
      visualViewport: { width: 400, height: 800 - (KEYBOARD_INSET_THRESHOLD - 1), offsetTop: 0 },
      editableFocused: true,
    });
    expect(s.keyboardOpen).toBe(false);
  });

  it("does not open the keyboard on desktop even with an inset", () => {
    const s = computeViewport({
      ...base,
      innerWidth: 1200,
      innerHeight: 800,
      visualViewport: { width: 1200, height: 500, offsetTop: 0 },
      editableFocused: true,
    });
    expect(s.keyboardOpen).toBe(false);
  });
});

describe("viewportPayload", () => {
  it("maps to the server's snake_case keys", () => {
    const payload = viewportPayload(computeViewport(base));
    expect(payload).toEqual({
      width: 1024,
      height: 768,
      visual_width: 1024,
      visual_height: 768,
      mobile: false,
    });
  });
});

describe("viewportChanged", () => {
  const a = { width: 1024, height: 768, mobile: false };

  it("is always true with no previous payload", () => {
    expect(viewportChanged(null, a)).toBe(true);
  });

  it("is false when the tracked fields are unchanged", () => {
    expect(viewportChanged(a, { ...a })).toBe(false);
  });

  it("ignores changes outside width/height/mobile", () => {
    expect(viewportChanged(a, { ...a, visual_width: 999 })).toBe(false);
  });

  it("is true when the breakpoint flips", () => {
    expect(viewportChanged(a, { ...a, mobile: true })).toBe(true);
  });
});

describe("viewportCssVars", () => {
  it("emits every custom property with a px unit", () => {
    const vars = viewportCssVars(computeViewport(base));
    expect(vars["--rhc-visual-viewport-height"]).toBe("768px");
    expect(vars["--rhc-keyboard-inset-bottom"]).toBe("0px");
    expect(Object.keys(vars)).toHaveLength(5);
  });
});
