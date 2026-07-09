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
    save: vi.fn(),
    scale: vi.fn(),
    restore: vi.fn(),
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
    layers: overrides.layers ?? undefined,
    collision: [],
    zones: [],
    seats: [],
    interactables: [],
    labels: overrides.labels ?? [],
  });
  const camera = new Camera({ tileSize: 16, scale: 2, mapWidth: 20, mapHeight: 15 });
  camera.setViewport(320, 240);
  const atlas = overrides.atlas ?? {
    tile: () => ({ canvas: {} }),
    avatar: () => ({ canvas: {} }),
  };
  return { ctx, renderer: new Renderer({ canvas, atlas, map, camera }) };
}

describe("Renderer map labels", () => {
  it("draws static room labels supplied by the map definition", () => {
    const { ctx, renderer } = build({
      labels: [{ id: "nameplate", kind: "nameplate", x: 2, y: 2, w: 6, h: 1, text: "Alice + Bob" }],
    });

    renderer.draw({ participants: new Map(), selfKey: null, bubbles: new Map() });

    const printed = ctx.fillText.mock.calls.map((c) => c[0]);
    expect(printed).toContain("Alice + Bob");
  });

  it("draws compact table nameplates supplied by the map definition", () => {
    const { ctx, renderer } = build({
      labels: [
        {
          id: "dm_nameplate",
          kind: "table_nameplate",
          x: 2,
          y: 2,
          w: 3,
          h: 1,
          text: "Alice + Bob",
        },
      ],
    });

    renderer.draw({ participants: new Map(), selfKey: null, bubbles: new Map() });

    const printed = ctx.fillText.mock.calls.map((c) => c[0]);
    expect(printed).toContain("Alice + Bob");
    expect(ctx.font).toBe("10px monospace");
  });
});

describe("Renderer flipped tiles", () => {
  it("mirrors tiles that request flipX without changing their world anchor", () => {
    const img = { complete: true, naturalWidth: 64 };
    const atlas = {
      tile: (name) =>
        name === "chair" ? { img, sx: 16, sy: 64, sw: 16, sh: 48, flipX: true } : null,
      avatar: () => null,
    };
    const { ctx, renderer } = build({
      atlas,
      layers: { floor: [], decor: [{ x: 2, y: 3, tile: "chair" }], above: [] },
    });

    renderer.draw({ participants: new Map(), selfKey: null, bubbles: new Map() });

    expect(ctx.save).toHaveBeenCalledTimes(1);
    expect(ctx.scale).toHaveBeenCalledWith(-1, 1);
    expect(ctx.drawImage).toHaveBeenCalledWith(img, 16, 64, 16, 48, -96, 96, 32, 96);
    expect(ctx.restore).toHaveBeenCalledTimes(1);
  });
});

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

  it("centers wide sword sprites on the avatar tile", () => {
    const img = { complete: true, naturalWidth: 32 };
    const atlas = {
      tile: () => null,
      avatar: vi.fn(() => ({ img, sx: 0, sy: 128, sw: 32, sh: 32 })),
      avatarFrameCount: vi.fn(() => 4),
    };
    const { ctx, renderer } = build({ atlas });
    const participants = new Map([
      [
        "registered:1",
        {
          key: "registered:1",
          nickname: "",
          avatar: "redtunic_hero",
          x: 5,
          y: 5,
          dir: "down",
          action: { kind: "sword", dir: "down", startedAt: 0, duration: 420 },
        },
      ],
    ]);

    renderer.draw({ participants, selfKey: "registered:1", bubbles: new Map(), now: 0 });

    expect(ctx.drawImage).toHaveBeenCalledWith(img, 0, 128, 32, 32, 144, 128, 64, 64);
  });
});
