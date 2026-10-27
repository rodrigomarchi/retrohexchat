import { describe, it, expect } from "vitest";
import { createLayer } from "../../../../js/lib/games/core/layers.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";

const make = (width, height) => recordingCanvas(width, height);

describe("createLayer", () => {
  it("holds as many pixels as the screen it is copied to", () => {
    const layer = createLayer(640, 480, 2, { createCanvas: make });
    expect([layer.canvas.width, layer.canvas.height]).toEqual([1280, 960]);
  });

  it("is drawn on in the game's own pixels, from its scale, every time it is cleared", () => {
    const layer = createLayer(640, 480, 2, { createCanvas: make });
    layer.ctx.translate(30, 30);
    layer.canvas.clearLog();
    layer.clear();

    expect(layer.canvas.log).toEqual([
      ["setTransform", 2, 0, 0, 2, 0, 0],
      ["imageSmoothingEnabled", "=", false],
      ["clearRect", 0, 0, 640, 480],
    ]);
  });

  it("copies itself onto a screen at the game's size", () => {
    const layer = createLayer(640, 480, 2, { createCanvas: make });
    const screen = make(1280, 960);
    screen.clearLog();
    layer.drawTo(screen.getContext("2d"));

    expect(screen.log).toHaveLength(1);
    expect(screen.log[0][0]).toBe("drawImage");
    expect(screen.log[0].slice(2)).toEqual([0, 0, 640, 480]);
  });

  it("has no context where the page cannot draw off the screen, and does not fail", () => {
    const blind = () => ({ width: 0, height: 0, getContext: () => null });
    const layer = createLayer(640, 480, 2, { createCanvas: blind });
    expect(layer.ctx).toBeNull();
    expect(() => layer.clear()).not.toThrow();
  });
});
