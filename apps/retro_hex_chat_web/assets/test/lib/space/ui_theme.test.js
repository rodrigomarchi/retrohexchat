import { describe, it, expect, afterEach } from "vitest";

import { readUiTheme, UI_FONT_PX } from "../../../js/lib/space/ui_theme.js";

const FALLBACK = {
  bubbleInk: "ink",
  labelInk: "label",
  signInk: "sign",
  damage: "dmg",
  damageKo: "ko",
  damageOutline: "outline",
  hologramInk: "holo",
  family: "monospace",
};

afterEach(() => {
  document.body.replaceChildren();
});

describe("readUiTheme", () => {
  it("reads the kit's colours and font from the page it draws in", () => {
    // A browser inherits these from `.space-ui`; jsdom does not cascade custom
    // properties, so the canvas carries them itself here.
    const canvas = document.createElement("canvas");
    canvas.style.setProperty("--space-ui-bubble-ink", "rgb(1, 2, 3)");
    canvas.style.fontFamily = '"RH Pixel", monospace';
    document.body.appendChild(canvas);

    const theme = readUiTheme(canvas, FALLBACK);
    expect(theme.bubbleInk).toBe("rgb(1, 2, 3)");
    expect(theme.labelInk).toBe("label");
    expect(theme.font).toBe(`${UI_FONT_PX}px "RH Pixel", monospace`);
  });

  it("keeps every fallback for a stand-in canvas", () => {
    const theme = readUiTheme({ getContext: () => null }, FALLBACK);
    expect(theme).toMatchObject({ bubbleInk: "ink", hologramInk: "holo" });
    expect(theme.font).toBe("12px monospace");
  });
});
