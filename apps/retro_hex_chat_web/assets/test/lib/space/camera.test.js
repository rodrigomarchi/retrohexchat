import { describe, it, expect } from "vitest";

import { Camera } from "../../../js/lib/space/camera.js";

describe("Camera", () => {
  it("centers on the target within a viewport", () => {
    // 40x30 tiles, tile 16, scale 2 => world 1280x960; viewport 320x240.
    const cam = new Camera({ tileSize: 16, scale: 2, mapWidth: 40, mapHeight: 30 });
    cam.setViewport(320, 240);
    cam.follow(20, 15);

    // Target tile center in world px = (20*16+8)*2 = 656; minus half viewport 160 => 496.
    expect(cam.x).toBe(496);
    expect(cam.y).toBe((15 * 16 + 8) * 2 - 120);
  });

  it("clamps to the map edges so it never shows past the world", () => {
    const cam = new Camera({ tileSize: 16, scale: 2, mapWidth: 40, mapHeight: 30 });
    cam.setViewport(320, 240);

    cam.follow(0, 0);
    expect(cam.x).toBe(0);
    expect(cam.y).toBe(0);

    cam.follow(39, 29);
    expect(cam.x).toBe(40 * 16 * 2 - 320);
    expect(cam.y).toBe(30 * 16 * 2 - 240);
  });

  it("does not clamp negative when the world is smaller than the viewport", () => {
    const cam = new Camera({ tileSize: 16, scale: 2, mapWidth: 4, mapHeight: 4 });
    cam.setViewport(320, 240);
    cam.follow(2, 2);
    expect(cam.x).toBe(0);
    expect(cam.y).toBe(0);
  });

  it("converts a world point to screen space", () => {
    const cam = new Camera({ tileSize: 16, scale: 2, mapWidth: 40, mapHeight: 30 });
    cam.setViewport(320, 240);
    cam.follow(20, 15);
    const screen = cam.worldToScreen(656, 496);
    expect(screen.x).toBe(656 - cam.x);
    expect(screen.y).toBe(496 - cam.y);
  });
});
