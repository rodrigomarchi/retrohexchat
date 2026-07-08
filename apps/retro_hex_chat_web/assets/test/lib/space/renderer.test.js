import { describe, it, expect, vi } from "vitest";

import { Renderer } from "../../../js/lib/space/renderer.js";
import { SpaceMap } from "../../../js/lib/space/map.js";
import { Camera } from "../../../js/lib/space/camera.js";

function mockCtx() {
  return {
    imageSmoothingEnabled: true,
    fillStyle: "",
    font: "",
    textAlign: "",
    clearRect: vi.fn(),
    fillRect: vi.fn(),
    fillText: vi.fn(),
    drawImage: vi.fn(),
    measureText: vi.fn(() => ({ width: 40 })),
    beginPath: vi.fn(),
    arc: vi.fn(),
    fill: vi.fn(),
  };
}

function build(overrides = {}) {
  const ctx = mockCtx();
  const canvas = { width: 320, height: 240, getContext: () => ctx };
  const map = SpaceMap.from({
    id: "t",
    width: 20,
    height: 15,
    tile_size: 16,
    spawn: [],
    collision: [],
    zones: [],
    seats: [],
    interactables: [],
  });
  const camera = new Camera({ tileSize: 16, scale: 2, mapWidth: 20, mapHeight: 15 });
  camera.setViewport(320, 240);
  const atlas = overrides.atlas ?? {
    tile: () => ({ canvas: {} }),
    avatar: () => ({ canvas: {} }),
  };
  return { ctx, renderer: new Renderer({ canvas, atlas, map, camera }) };
}

describe("Renderer speech bubbles", () => {
  it("draws bubble text as text via fillText (never as HTML)", () => {
    const { ctx, renderer } = build();
    const participants = new Map([
      ["registered:1", { key: "registered:1", nickname: "alice", x: 5, y: 5, dir: "down" }],
    ]);
    const bubbles = new Map([["registered:1", "<b>hi & bye</b>"]]);

    renderer.draw({ participants, selfKey: "registered:1", bubbles });

    // The raw string is rendered verbatim through fillText — canvas text never
    // interprets markup, so there is no HTML-injection surface.
    const printed = ctx.fillText.mock.calls.map((c) => c[0]);
    expect(printed).toContain("<b>hi & bye</b>");
  });

  it("does not draw a bubble when the participant has none", () => {
    const { ctx, renderer } = build();
    const participants = new Map([
      ["registered:1", { key: "registered:1", nickname: "alice", x: 5, y: 5, dir: "down" }],
    ]);

    renderer.draw({ participants, selfKey: "registered:1", bubbles: new Map() });

    const printed = ctx.fillText.mock.calls.map((c) => c[0]);
    // Only the nickname label is printed, no bubble body.
    expect(printed).toEqual(["alice"]);
  });
});

describe("Renderer avatar actions", () => {
  it("requests sword frames from the atlas while an action is active", () => {
    const atlas = {
      tile: () => null,
      avatar: vi.fn(() => null),
      avatarFrameCount: vi.fn(() => 4),
    };
    const { renderer } = build({ atlas });
    const participants = new Map([
      [
        "registered:1",
        {
          key: "registered:1",
          nickname: "alice",
          avatar: "redtunic_hero",
          x: 5,
          y: 5,
          dir: "down",
          action: { kind: "sword", dir: "left", startedAt: 0, duration: 420 },
        },
      ],
    ]);

    renderer.draw({ participants, selfKey: "registered:1", bubbles: new Map(), now: 210 });

    expect(atlas.avatar).toHaveBeenCalledWith("redtunic_hero", "left", 2, "sword");
  });
});
