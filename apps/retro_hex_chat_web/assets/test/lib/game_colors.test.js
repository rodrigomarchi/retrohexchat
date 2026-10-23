import { describe, it, expect, afterEach } from "vitest";
import { readGameColors } from "../../js/lib/game_colors.js";

describe("readGameColors", () => {
  let canvas;

  afterEach(() => canvas?.remove());

  it("reads each colour from its custom property, falling back when unset", () => {
    canvas = document.createElement("canvas");
    canvas.style.setProperty("--game-bg-color", "#123456");
    document.body.appendChild(canvas);

    const colors = readGameColors(canvas, {
      bg: ["--game-bg-color", "0a0a1a"],
      fg: ["--game-fg-color", "00ffcc"],
      line: ["--game-line-color", "39ff1480"],
      glow: ["--game-glow-color", "rgba(0,255,204,0.2)"],
    });

    expect(colors.bg).toBe("#123456");
    expect(colors.fg).toBe("#00ffcc");
    expect(colors.line).toBe("#39ff1480");
    expect(colors.glow).toBe("rgba(0,255,204,0.2)");
  });
});
