import { describe, it, expect, vi } from "vitest";

import { Renderer } from "../../../js/lib/space/renderer.js";
import { SpaceMap } from "../../../js/lib/space/map.js";
import { Camera } from "../../../js/lib/space/camera.js";
import { createProjection } from "../../../js/lib/space/projection.js";

function mockCtx() {
  return {
    imageSmoothingEnabled: true,
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 1,
    font: "",
    textAlign: "",
    stroke: vi.fn(),
    clearRect: vi.fn(),
    fillRect: vi.fn(),
    fillText: vi.fn(),
    drawImage: vi.fn(),
    measureText: vi.fn(() => ({ width: 40 })),
    save: vi.fn(),
    scale: vi.fn(),
    translate: vi.fn(),
    restore: vi.fn(),
    beginPath: vi.fn(),
    arc: vi.fn(),
    moveTo: vi.fn(),
    lineTo: vi.fn(),
    closePath: vi.fn(),
    fill: vi.fn(),
    createRadialGradient: vi.fn(() => ({ addColorStop: vi.fn() })),
    createLinearGradient: vi.fn(() => ({ addColorStop: vi.fn() })),
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
    lights: overrides.lights ?? undefined,
    ambient: overrides.ambient ?? undefined,
    parallax: overrides.parallax ?? undefined,
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
    // Anchored on the iso floor diamond of tile (2,3); flipX mirrors in place.
    expect(ctx.drawImage).toHaveBeenCalledWith(img, 16, 64, 16, 48, -928, 352, 32, 96);
    expect(ctx.restore).toHaveBeenCalledTimes(1);
  });
});

describe("Renderer depth sorting (walk-behind)", () => {
  // A stand prop and an avatar share one Y-sorted pass so the avatar passes
  // behind taller props. We tag each draw by a distinct source-y so the call
  // order is legible in the drawImage mock.
  const img = { complete: true, naturalWidth: 64 };
  const PROP = { img, sx: 0, sy: 700, sw: 32, sh: 64, flipX: false }; // 4 tiles tall
  const AVATAR = { img, sx: 0, sy: 100, sw: 16, sh: 32 };

  function drawnOrder(propY, avatarY) {
    const atlas = {
      tile: (name) => (name === "lamp" ? PROP : null),
      avatar: () => AVATAR,
      avatarFrameCount: () => 4,
    };
    const { ctx, renderer } = build({
      atlas,
      layers: { floor: [], decor: [{ x: 4, y: propY, tile: "lamp", sort: "stand" }], above: [] },
    });
    const participants = new Map([
      [
        "registered:1",
        {
          key: "registered:1",
          nickname: "",
          avatar: "hero",
          x: 4,
          y: avatarY,
          dir: "down",
        },
      ],
    ]);
    renderer.draw({ participants, selfKey: "registered:1", bubbles: new Map(), now: 0 });
    // Map each drawImage to "prop" or "avatar" by its source-y.
    return ctx.drawImage.mock.calls.map((c) => (c[2] === 700 ? "prop" : "avatar"));
  }

  it("draws the avatar BEHIND a prop whose base is below the avatar's feet", () => {
    // prop base row = 3 + 4 = 7; avatar feet row = 2 + 1 = 3 → avatar first (behind).
    expect(drawnOrder(3, 2)).toEqual(["avatar", "prop"]);
  });

  it("draws the avatar IN FRONT of a prop whose base is above the avatar's feet", () => {
    // prop base row = 3 + 4 = 7; avatar feet row = 8 + 1 = 9 → prop first (avatar in front).
    expect(drawnOrder(3, 8)).toEqual(["prop", "avatar"]);
  });

  it("keeps flat decor (stars) under every avatar regardless of Y", () => {
    const star = { img, sx: 0, sy: 900, sw: 16, sh: 16 };
    const atlas = {
      tile: (name) => (name === "star" ? star : null),
      avatar: () => AVATAR,
      avatarFrameCount: () => 4,
    };
    const { ctx, renderer } = build({
      atlas,
      // a star far below the avatar; without the flat rule its baseline would sort it on top.
      layers: { floor: [], decor: [{ x: 4, y: 12, tile: "star", sort: "flat" }], above: [] },
    });
    const participants = new Map([
      [
        "registered:1",
        { key: "registered:1", nickname: "", avatar: "hero", x: 4, y: 2, dir: "down" },
      ],
    ]);
    renderer.draw({ participants, selfKey: "registered:1", bubbles: new Map(), now: 0 });
    const order = ctx.drawImage.mock.calls.map((c) => (c[2] === 900 ? "star" : "avatar"));
    expect(order).toEqual(["star", "avatar"]);
  });
});

describe("Renderer isometric", () => {
  const img = { complete: true, naturalWidth: 64 };
  // Build a small iso map; tile sprites encode x+y in their source-y so draw
  // order is legible. Void ("g") tiles are skipped so the platform floats.
  function isoBuild({ floor, decor = [], participants = new Map(), slab, slabs, vignette, sea }) {
    const ctx = mockCtx();
    const canvas = { width: 640, height: 480, getContext: () => ctx };
    const def = {
      id: "iso",
      width: 4,
      height: 4,
      tile_size: 16,
      projection: "isometric",
      iso: { tile_w: 64, tile_h: 32, z_step: 16 },
      ground: "g",
      spawn: [],
      collision: [],
      zones: [],
      seats: [],
      interactables: [],
      labels: [],
      slab,
      slabs,
      vignette,
      sea,
      layers: { floor, decor, above: [] },
    };
    const map = SpaceMap.from(def);
    const projection = createProjection({
      map: def,
      tileSize: 16,
      scale: 2,
      mapWidth: 4,
      mapHeight: 4,
    });
    const camera = new Camera({ tileSize: 16, scale: 2, mapWidth: 4, mapHeight: 4, projection });
    camera.setViewport(640, 480);
    const atlas = {
      // floor "d<n>" → sy=n*10; the "block" prop → sy=500; avatar → sy=999.
      tile: (name) => {
        if (name === "block") return { img, sx: 0, sy: 500, sw: 32, sh: 96 };
        if (name?.startsWith?.("d")) {
          return { img, sx: 0, sy: Number(name.slice(1)) * 10, sw: 32, sh: 32 };
        }
        return null;
      },
      avatar: () => ({ img, sx: 0, sy: 999, sw: 16, sh: 32 }),
      avatarFrameCount: () => 4,
    };
    const renderer = new Renderer({ canvas, atlas, map, camera });
    renderer.draw({ participants, selfKey: null, bubbles: new Map(), now: 0 });
    return ctx;
  }

  it("paints iso floor tiles far→near (ascending x+y) and skips void tiles", () => {
    const floor = [
      ["d0", "d1", "g", "g"],
      ["d1", "d2", "d3", "g"],
      ["g", "d3", "d4", "d5"],
      ["g", "g", "d5", "d6"],
    ];
    const ctx = isoBuild({ floor });
    const floorSy = ctx.drawImage.mock.calls.map((c) => c[2]).filter((sy) => sy < 900);
    // non-decreasing = far→near; and no void tile (there is no "g" sprite) drawn.
    const sorted = [...floorSy].sort((a, b) => a - b);
    expect(floorSy).toEqual(sorted);
    expect(floorSy.length).toBe(10); // 10 non-void cells (the rest are "g" → skipped)
  });

  function isoDepthOrder(propXY, avatarXY) {
    const floor = [
      ["d0", "d0", "d0", "d0"],
      ["d0", "d0", "d0", "d0"],
      ["d0", "d0", "d0", "d0"],
      ["d0", "d0", "d0", "d0"],
    ];
    const ctx = isoBuild({
      floor,
      decor: [{ x: propXY[0], y: propXY[1], tile: "block", sort: "stand" }],
      participants: new Map([
        ["k", { key: "k", avatar: "hero", x: avatarXY[0], y: avatarXY[1], dir: "down" }],
      ]),
    });
    return ctx.drawImage.mock.calls
      .map((c) => c[2])
      .filter((sy) => sy === 500 || sy === 999)
      .map((sy) => (sy === 500 ? "prop" : "avatar"));
  }

  it("walk-behind: avatar in FRONT of a prop with smaller x+y", () => {
    // prop at (0,0) x+y=0; avatar at (3,3) depthKey=6.5 → prop first, avatar in front.
    expect(isoDepthOrder([0, 0], [3, 3])).toEqual(["prop", "avatar"]);
  });

  it("walk-behind: avatar BEHIND a prop with larger x+y", () => {
    // prop at (3,3) x+y=6; avatar at (0,0) depthKey=0.5 → avatar first, behind.
    expect(isoDepthOrder([3, 3], [0, 0])).toEqual(["avatar", "prop"]);
  });

  it("draws the slab undersides (front faces) when the map has slabs", () => {
    const floor = [
      ["d0", "d0", "d0"],
      ["d0", "d0", "d0"],
      ["d0", "d0", "d0"],
    ];
    const withSlab = isoBuild({ floor, slabs: [{ thickness: 4, taper: 0.6, hull: [0, 2, 0, 2] }] });
    const withoutSlab = isoBuild({ floor });
    // The underside faces are the only polygons (moveTo); floor/props are blits.
    expect(withSlab.moveTo.mock.calls.length).toBeGreaterThan(0);
    expect(withoutSlab.moveTo.mock.calls.length).toBe(0);
  });

  it("draws multiple slabs far→near so a nearer block paints over a farther one", () => {
    const floor = [
      ["d0", "g", "g"],
      ["g", "g", "g"],
      ["g", "g", "d0"],
    ];
    const near = { thickness: 2, taper: 0, hull: [2, 2, 2, 2] };
    const far = { thickness: 2, taper: 0, hull: [0, 0, 0, 0] };
    const ctx = isoBuild({ floor, slabs: [near, far] });
    // Two front faces per slab → 4 polygons; the far slab (smaller hull front
    // corner) must draw first, and its vertices sit higher on screen (smaller y).
    expect(ctx.moveTo.mock.calls.length).toBe(4);
    expect(ctx.moveTo.mock.calls[0][1]).toBeLessThan(ctx.moveTo.mock.calls[2][1]);
  });

  it("wraps a legacy single `slab` payload into the slabs list", () => {
    const floor = [["d0"]];
    const ctx = isoBuild({ floor, slab: { thickness: 4, taper: 0.6, hull: [0, 0, 0, 0] } });
    expect(ctx.moveTo.mock.calls.length).toBe(2);
  });

  it("draws the cosmic sea (linear gradient + ripple bands) when the map defines one", () => {
    const floor = [["d0"]];
    const withSea = isoBuild({ floor, sea: { top: "0c1e42", bottom: "05060f", bands: 6 } });
    const withoutSea = isoBuild({ floor });
    expect(withSea.createLinearGradient).toHaveBeenCalled();
    expect(withSea.moveTo).toHaveBeenCalled(); // the wavy ripple bands
    expect(withoutSea.createLinearGradient).not.toHaveBeenCalled();
  });

  it("applies a vignette (radial multiply) when the map defines one", () => {
    const floor = [["d0"]];
    const withVig = isoBuild({ floor, vignette: { color: "05060f", alpha: 0.7 } });
    const withoutVig = isoBuild({ floor });
    // No lights in either map → the only radial gradient is the vignette.
    expect(withVig.createRadialGradient).toHaveBeenCalledTimes(1);
    expect(withoutVig.createRadialGradient).not.toHaveBeenCalled();
  });
});

describe("Renderer parallax", () => {
  it("tiles a parallax layer across the viewport behind the floor", () => {
    const img = { complete: true, naturalWidth: 160 };
    const atlas = {
      tile: (name) => (name === "neb" ? { img, sx: 0, sy: 288, sw: 160, sh: 96 } : null),
      avatar: () => null,
    };
    const { ctx, renderer } = build({
      atlas,
      parallax: [{ tile: "neb", scroll: 0.3, alpha: 0.5, step: 6 }],
    });
    renderer.draw({ participants: new Map(), selfKey: null, bubbles: new Map() });
    // The 320×240 viewport tiled by a stepped nebula draws it several times.
    const nebulaBlits = ctx.drawImage.mock.calls.filter((c) => c[2] === 288);
    expect(nebulaBlits.length).toBeGreaterThan(1);
  });

  it("skips parallax on maps that define none", () => {
    const img = { complete: true, naturalWidth: 160 };
    const atlas = {
      tile: (name) => (name === "neb" ? { img, sx: 0, sy: 288, sw: 160, sh: 96 } : null),
      avatar: () => null,
    };
    const { ctx, renderer } = build({ atlas });
    renderer.draw({ participants: new Map(), selfKey: null, bubbles: new Map() });
    expect(ctx.drawImage.mock.calls.filter((c) => c[2] === 288).length).toBe(0);
  });
});

describe("Renderer color-math lighting", () => {
  it("draws one additive radial pool per map light", () => {
    const { ctx, renderer } = build({
      lights: [
        { x: 5, y: 5, radius: 4, color: "ffd591", blend: "add" },
        { x: 9, y: 3, radius: 3, color: "7fd6e6", blend: "add" },
      ],
    });
    renderer.draw({ participants: new Map(), selfKey: null, bubbles: new Map() });
    expect(ctx.createRadialGradient).toHaveBeenCalledTimes(2);
  });

  it("applies an ambient multiply wash when the map defines one", () => {
    const { ctx, renderer } = build({ ambient: { color: "1a1533", alpha: 0.42 } });
    renderer.draw({ participants: new Map(), selfKey: null, bubbles: new Map() });
    // The void backdrop plus the ambient wash both fill the whole canvas.
    const fullScreen = ctx.fillRect.mock.calls.filter(
      (c) => c[0] === 0 && c[1] === 0 && c[2] === 320 && c[3] === 240,
    );
    expect(fullScreen.length).toBe(2);
  });

  it("leaves maps without lighting untouched (no pools, single backdrop fill)", () => {
    const { ctx, renderer } = build();
    renderer.draw({ participants: new Map(), selfKey: null, bubbles: new Map() });
    expect(ctx.createRadialGradient).not.toHaveBeenCalled();
    const fullScreen = ctx.fillRect.mock.calls.filter(
      (c) => c[0] === 0 && c[1] === 0 && c[2] === 320 && c[3] === 240,
    );
    expect(fullScreen.length).toBe(1);
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
          avatar: "hero",
          x: 5,
          y: 5,
          action: { kind: "sword", startedAt: 0, duration: 420 },
        },
      ],
    ]);

    renderer.draw({ participants, selfKey: "registered:1", bubbles: new Map(), now: 210 });

    // Iso avatars face their last movement direction (south when still), not the
    // action payload; 210/420 of a 4-frame swing → frame 2.
    expect(atlas.avatar).toHaveBeenCalledWith("hero", "south", 2, "sword");
  });

  it("billboards a wide sword sprite bottom-centre on the diamond foot", () => {
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
          avatar: "hero",
          x: 5,
          y: 5,
          action: { kind: "sword", startedAt: 0, duration: 420 },
        },
      ],
    ]);

    renderer.draw({ participants, selfKey: "registered:1", bubbles: new Map(), now: 0 });

    // foot of tile (5,5) → (1024,544); 32×32 sprite at scale 2 billboards to
    // (992,480), 64×64.
    expect(ctx.drawImage).toHaveBeenCalledWith(img, 0, 128, 32, 32, 992, 480, 64, 64);
  });
});

describe("Renderer avatar pose state machine", () => {
  function poseRenderer(metaOverrides = {}) {
    const atlas = {
      tile: () => null,
      avatar: () => ({ canvas: {} }),
      avatarMeta: () => ({ hasIdle: true, hasIdle2: true, hasSleep: true, ...metaOverrides }),
      avatarFrameCount: () => 4,
    };
    return build({ atlas }).renderer;
  }

  it("alternates an avatar with a second idle stance across the slow idle cycle", () => {
    const renderer = poseRenderer();
    const participant = { key: "u1", avatar: "knight", x: 3, y: 4 };
    renderer._avatarPose(participant, 0);
    const kinds = new Set();
    // One full 9s cycle inside the idle band (after walk settles, before sleep).
    for (let t = 1000; t < 10000; t += 200) {
      kinds.add(renderer._avatarPose(participant, t).actionKind);
    }
    expect(kinds).toEqual(new Set(["idle", "idle2"]));
  });

  it("keeps a single-idle avatar on its only idle stance", () => {
    const renderer = poseRenderer({ hasIdle2: false });
    const participant = { key: "u2", avatar: "hero", x: 3, y: 4 };
    renderer._avatarPose(participant, 0);
    for (let t = 1000; t < 10000; t += 200) {
      expect(renderer._avatarPose(participant, t).actionKind).toBe("idle");
    }
  });

  it("desyncs the idle2 stretches of different participants by key", () => {
    const renderer = poseRenderer();
    const a = { key: "alice", avatar: "knight", x: 1, y: 1 };
    const b = { key: "bob-the-long-key", avatar: "knight", x: 2, y: 2 };
    renderer._avatarPose(a, 0);
    renderer._avatarPose(b, 0);
    const diverged = [];
    for (let t = 1000; t < 10000; t += 200) {
      diverged.push(
        renderer._avatarPose(a, t).actionKind !== renderer._avatarPose(b, t).actionKind,
      );
    }
    expect(diverged).toContain(true);
  });

  it("sleeps facing the direction of the last step", () => {
    const renderer = poseRenderer();
    const participant = { key: "u3", avatar: "knight", x: 3, y: 4 };
    renderer._avatarPose(participant, 0);
    participant.x = 2; // step (-1,0) reads as north-west on screen
    renderer._avatarPose(participant, 100);
    const pose = renderer._avatarPose(participant, 100 + 13000);
    expect(pose).toMatchObject({ actionKind: "sleep", dir: "north-west" });
  });
});
