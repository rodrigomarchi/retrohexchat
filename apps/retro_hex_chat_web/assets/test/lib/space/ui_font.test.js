import { describe, it, expect, vi } from "vitest";

import { createGlyphLoader } from "../../../js/lib/space/ui_font.js";

function fontSet({ loaded = false } = {}) {
  return { check: vi.fn(() => loaded), load: vi.fn(() => Promise.resolve([])) };
}

describe("createGlyphLoader", () => {
  it("asks the font set for glyphs it has not seen", () => {
    const fonts = fontSet();
    createGlyphLoader(fonts, "12px RH Pixel").ensure("你好 hi");
    expect(fonts.load).toHaveBeenCalledWith("12px RH Pixel", "你好 hi");
  });

  it("asks once per glyph, so a bubble redrawn every frame costs nothing", () => {
    const fonts = fontSet();
    const glyphs = createGlyphLoader(fonts, "12px RH Pixel");
    glyphs.ensure("abc");
    glyphs.ensure("abc");
    glyphs.ensure("abd");
    expect(fonts.load).toHaveBeenCalledTimes(2);
    expect(fonts.load).toHaveBeenLastCalledWith("12px RH Pixel", "d");
  });

  it("loads nothing the font set already holds", () => {
    const fonts = fontSet({ loaded: true });
    createGlyphLoader(fonts, "12px RH Pixel").ensure("hello");
    expect(fonts.load).not.toHaveBeenCalled();
  });

  it("does nothing without a font set", () => {
    expect(() => createGlyphLoader(null, "12px x").ensure("hi")).not.toThrow();
  });
});
