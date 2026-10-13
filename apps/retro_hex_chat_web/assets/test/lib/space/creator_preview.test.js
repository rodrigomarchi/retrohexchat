import { describe, expect, it } from "vitest";

import { createCreatorPreview } from "../../../js/lib/space/creator_preview.js";

const DIRS = [
  "south",
  "south-east",
  "east",
  "north-east",
  "north",
  "north-west",
  "west",
  "south-west",
];

function setup({ reducedMotion = false } = {}) {
  document.body.innerHTML = `
    <div id="p" data-recipe="c1.a" data-character-catalog="/catalog.json">
      <canvas data-creator-canvas></canvas>
      <button data-creator-turn="-1">left</button>
      <button data-creator-turn="1">right</button>
    </div>`;
  const el = document.getElementById("p");
  const drawn = [];
  const prepared = [];
  const frames = [];
  const compositor = {
    catalog: { dirs: DIRS },
    frameSize: { w: 50, h: 100 },
    frames: () => 4,
    strip: (recipe, anim, dir) => ({ recipe, anim, dir }),
    prepareAll: (recipe, anims) => prepared.push([recipe, anims]),
  };
  const canvas = el.querySelector("canvas");
  canvas.getContext = () => ({
    clearRect: () => {},
    drawImage: (strip, sx) => drawn.push({ ...strip, sx }),
  });
  let loaded;
  const preview = createCreatorPreview(el, {
    load: (url) => {
      expect(url).toBe("/catalog.json");
      return new Promise((resolve) => (loaded = () => resolve(compositor)));
    },
    requestFrame: (cb) => frames.push(cb),
    cancelFrame: () => {},
    reducedMotion: () => reducedMotion,
  });
  const tick = (now) => frames.splice(0).forEach((cb) => cb(now));
  const ready = async () => {
    loaded();
    await Promise.resolve();
    await Promise.resolve();
  };
  return { el, canvas, preview, drawn, prepared, tick, ready };
}

describe("creator preview", () => {
  it("draws the character walking, at twice its size", async () => {
    const t = setup();
    await t.ready();
    expect(t.canvas.width).toBe(100);
    expect(t.canvas.height).toBe(200);
    t.tick(250);
    expect(t.drawn.at(-1)).toEqual({ recipe: "c1.a", anim: "walk", dir: "south", sx: 100 });
    expect(t.prepared).toEqual([["c1.a", ["walk"]]]);
  });

  it("turns with the keys under it, round the eight facings", async () => {
    const t = setup();
    await t.ready();
    t.el.querySelector('[data-creator-turn="-1"]').click();
    expect(t.preview.facing).toBe("south-west");
    t.el.querySelector('[data-creator-turn="1"]').click();
    t.el.querySelector('[data-creator-turn="1"]').click();
    expect(t.preview.facing).toBe("south-east");
  });

  it("draws the new character when the LiveView renders another recipe", async () => {
    const t = setup();
    await t.ready();
    t.el.dataset.recipe = "c1.b";
    t.preview.update();
    t.tick(0);
    expect(t.drawn.at(-1).recipe).toBe("c1.b");
  });

  it("stands still for somebody who asked for less motion", async () => {
    const t = setup({ reducedMotion: true });
    await t.ready();
    t.tick(999);
    expect(t.drawn.at(-1)).toMatchObject({ anim: "idle", sx: 0 });
  });

  it("composes nothing when it was closed before the catalog arrived", async () => {
    const t = setup();
    t.preview.destroy();
    await t.ready();
    expect(t.prepared).toEqual([]);
  });
});
