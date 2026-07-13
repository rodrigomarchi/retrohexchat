import { describe, it, expect } from "vitest";

import { Camera } from "../../../js/lib/space/camera.js";
import { createProjection } from "../../../js/lib/space/projection.js";

const ISO_MAP = { projection: "isometric", iso: { tile_w: 64, tile_h: 32, z_step: 16 } };

function isoCamera({ mapWidth, mapHeight, viewport }) {
  const projection = createProjection({ map: ISO_MAP, scale: 2, mapWidth, mapHeight });
  const cam = new Camera({ tileSize: 16, scale: 2, mapWidth, mapHeight, projection });
  cam.setViewport(viewport[0], viewport[1]);
  return { cam, projection };
}

describe("Camera", () => {
  it("centers on the target's diamond foot within a viewport", () => {
    // 40x30 iso map; a middle tile sits far from every edge, so no clamp applies.
    const { cam, projection } = isoCamera({ mapWidth: 40, mapHeight: 30, viewport: [320, 240] });
    cam.follow(20, 15);
    const foot = projection.footAnchor(20, 15);
    expect(cam.x).toBe(foot.x - 160);
    expect(cam.y).toBe(foot.y - 120);
  });

  it("clamps to the map edges so it never shows past the world", () => {
    const { cam, projection } = isoCamera({ mapWidth: 40, mapHeight: 30, viewport: [320, 240] });
    const bounds = projection.worldBounds();
    const maxX = bounds.width - 320;
    const maxY = bounds.height - 240;
    // The leftmost tile pulls the view hard against the x=0 edge…
    cam.follow(0, 29);
    expect(cam.x).toBe(0);
    expect(cam.y).toBeGreaterThanOrEqual(0);
    expect(cam.y).toBeLessThanOrEqual(maxY);
    // …and the far tile pins it to the far x edge, never revealing past the world.
    cam.follow(39, 0);
    expect(cam.x).toBe(maxX);
    cam.follow(39, 29);
    expect(cam.x).toBeGreaterThanOrEqual(0);
    expect(cam.x).toBeLessThanOrEqual(maxX);
    expect(cam.y).toBeGreaterThanOrEqual(0);
    expect(cam.y).toBeLessThanOrEqual(maxY);
  });

  it("does not clamp negative when the world is smaller than the viewport", () => {
    // A tiny map inside a huge viewport → the camera pins to the origin.
    const { cam } = isoCamera({ mapWidth: 4, mapHeight: 4, viewport: [2000, 2000] });
    cam.follow(2, 2);
    expect(cam.x).toBe(0);
    expect(cam.y).toBe(0);
  });

  it("converts a world point to screen space", () => {
    const { cam } = isoCamera({ mapWidth: 40, mapHeight: 30, viewport: [320, 240] });
    cam.follow(20, 15);
    const screen = cam.worldToScreen(656, 496);
    expect(screen.x).toBe(656 - cam.x);
    expect(screen.y).toBe(496 - cam.y);
  });
});
