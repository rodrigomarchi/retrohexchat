import { describe, it, expect, vi } from "vitest";

import { Renderer } from "../../../js/lib/space/renderer.js";
import { SpaceMap } from "../../../js/lib/space/map.js";
import { Camera } from "../../../js/lib/space/camera.js";
import { createProjection } from "../../../js/lib/space/projection.js";

const RECIPE = "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0";

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
  });
  const camera = new Camera({ tileSize: 16, scale: 2, mapWidth: 20, mapHeight: 15 });
  camera.setViewport(320, 240);
  const atlas = overrides.atlas ?? {
    tile: () => ({ canvas: {} }),
    avatar: () => ({ canvas: {} }),
  };
  return { ctx, renderer: new Renderer({ canvas, atlas, map, camera }) };
}

describe("Renderer depth of a piece", () => {
  it("sorts a prop by the depth it carries, not by where its art stands", () => {
    const decor = [
      // Art standing forward of an avatar, but sorted behind it.
      { x: 5, y: 5, tile: "table", sort: "stand", depth: 2 },
    ];
    const drawn = [];
    const { ctx, renderer } = build({
      layers: { floor: [], decor, above: [] },
      atlas: { tile: () => ({ canvas: {}, sw: 32, sh: 32 }), avatar: () => null },
    });
    renderer._blitBillboard = () => drawn.push("table");
    renderer._drawAvatar = () => drawn.push("avatar");
    renderer._drawDepthSorted(ctx, new Map([["a", { x: 3, y: 3 }]]));
    expect(drawn).toEqual(["table", "avatar"]);
  });
});

describe("Renderer railings", () => {
  it("draws a cell's back rail and back post behind what stands on the cell", () => {
    const decor = [{ x: 4, y: 4, tile: "gate", sort: "stand" }];
    const drawn = [];
    const { ctx, renderer } = build({
      layers: { floor: [], decor, above: [] },
      atlas: { tile: () => ({ canvas: {}, sw: 32, sh: 64 }), avatar: () => null },
    });
    renderer.map.railings = [
      { x: 4, y: 4, edge: "tr" },
      { x: 4, y: 4, edge: "bl" },
    ];
    renderer.map.railingPosts = [{ x: 4, y: 4, corner: "n" }];
    renderer._blitBillboard = () => drawn.push("gate");
    renderer._drawRailingTile = (_ctx, r) => drawn.push(`rail ${r.edge}`);
    renderer._drawRailingPost = (_ctx, p) => drawn.push(`post ${p.corner}`);
    renderer._drawDepthSorted(ctx, new Map());
    // The back post caps its rail, and both stand behind the gate.
    expect(drawn).toEqual(["rail tr", "post n", "gate", "rail bl"]);
  });
});

describe("Renderer contact shadows", () => {
  it("lays one under a standing prop, and none under one that stands flush", () => {
    const decor = [
      { x: 2, y: 2, tile: "lamp", sort: "stand" },
      { x: 4, y: 2, tile: "wall", sort: "stand", shadow: false },
    ];
    const { ctx, renderer } = build({
      layers: { floor: [], decor, above: [] },
      atlas: { tile: () => ({ canvas: {}, sw: 32, sh: 64 }), avatar: () => null },
    });
    renderer._drawShadows(ctx, new Map());
    expect(ctx.arc).toHaveBeenCalledTimes(1);
  });
});

describe("Renderer map labels", () => {
  it("draws the map's holograms and nothing for a label of another kind", () => {
    const { ctx, renderer } = build({
      labels: [
        { id: "dm", kind: "hologram", x: 2, y: 2, w: 6, h: 1, text: "Alice + Bob", lift: 150 },
        { id: "old", kind: "nameplate", x: 4, y: 4, w: 6, h: 1, text: "Unknown" },
      ],
    });

    renderer.draw({ participants: new Map(), selfKey: null, bubbles: new Map() });

    const printed = ctx.fillText.mock.calls.map((c) => c[0]);
    expect(printed).toContain("Alice + Bob");
    expect(printed).not.toContain("Unknown");
    // No `.space-ui` page around a stand-in canvas: the pixel font's size, the
    // generic family.
    expect(ctx.font).toBe("12px monospace");
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
          avatar: "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0",
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
        {
          key: "registered:1",
          nickname: "",
          avatar: "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0",
          x: 4,
          y: 2,
          dir: "down",
        },
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
        [
          "k",
          {
            key: "k",
            avatar: "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0",
            x: avatarXY[0],
            y: avatarXY[1],
            dir: "down",
          },
        ],
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
          avatar: "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0",
          x: 5,
          y: 5,
          action: { kind: "sword", startedAt: 0, duration: 420 },
        },
      ],
    ]);

    renderer.draw({ participants, selfKey: "registered:1", bubbles: new Map(), now: 210 });

    // Iso avatars face their last movement direction (south when still), not the
    // action payload; 210/420 of a 4-frame swing → frame 2.
    expect(atlas.avatar).toHaveBeenCalledWith(
      "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0",
      "south",
      2,
      "sword",
    );
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
          avatar: "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0",
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
    const participant = {
      key: "u1",
      avatar: "c1.b-av.s-4.o-tun-8-6.h-0.w-adv-d-6.f-0",
      x: 3,
      y: 4,
    };
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
    const participant = { key: "u2", avatar: "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0", x: 3, y: 4 };
    renderer._avatarPose(participant, 0);
    for (let t = 1000; t < 10000; t += 200) {
      expect(renderer._avatarPose(participant, t).actionKind).toBe("idle");
    }
  });

  it("desyncs the idle2 stretches of different participants by key", () => {
    const renderer = poseRenderer();
    const a = { key: "alice", avatar: "c1.b-av.s-4.o-tun-8-6.h-0.w-adv-d-6.f-0", x: 1, y: 1 };
    const b = {
      key: "bob-the-long-key",
      avatar: "c1.b-av.s-4.o-tun-8-6.h-0.w-adv-d-6.f-0",
      x: 2,
      y: 2,
    };
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
    const participant = {
      key: "u3",
      avatar: "c1.b-av.s-4.o-tun-8-6.h-0.w-adv-d-6.f-0",
      x: 3,
      y: 4,
    };
    renderer._avatarPose(participant, 0);
    participant.x = 2; // step (-1,0) reads as north-west on screen
    renderer._avatarPose(participant, 100);
    const pose = renderer._avatarPose(participant, 100 + 13000);
    expect(pose).toMatchObject({ actionKind: "sleep", dir: "north-west" });
  });
});

describe("Renderer combat poses", () => {
  function combatRenderer() {
    const atlas = {
      tile: () => null,
      avatar: () => ({ canvas: {} }),
      avatarMeta: () => ({ hasIdle: true, hasIdle2: false, hasSleep: true }),
      avatarFrameCount: () => 4,
    };
    return build({ atlas }).renderer;
  }

  it("plays hit, ko and getup from the action stream", () => {
    const renderer = combatRenderer();
    for (const kind of ["hit", "ko", "getup"]) {
      const participant = {
        key: `u-${kind}`,
        avatar: "c1.b-av.s-4.o-tun-8-6.h-0.w-adv-d-6.f-0",
        x: 3,
        y: 4,
        pose: kind === "ko" ? "down" : "standing",
        action: { kind, startedAt: 0, duration: 600 },
      };
      const pose = renderer._avatarPose(participant, 300);
      expect(pose.actionKind).toBe(kind);
    }
  });

  it("holds the last ko frame while a participant stays down", () => {
    const renderer = combatRenderer();
    const participant = {
      key: "u9",
      avatar: "c1.b-av.s-4.o-tun-8-6.h-0.w-adv-d-6.f-0",
      x: 3,
      y: 4,
      pose: "down",
      action: null,
    };
    renderer._avatarPose(participant, 0);
    const pose = renderer._avatarPose(participant, 20000); // long past the sleep threshold
    expect(pose).toMatchObject({ actionKind: "ko", frame: 3 });
  });
});

describe("Renderer combat feedback effects", () => {
  function fxRenderer() {
    const atlas = {
      tile: () => null,
      avatar: () => ({ canvas: {}, sw: 188, sh: 146 }),
      avatarMeta: () => ({ hasIdle: true, hasSleep: true }),
      avatarFrameCount: () => 4,
      avatarBounds: () => ({ top: 49, foot: 140 }),
      fx: () => null, // no fx sheet in tests; sparks skip drawing
      fxFrameCount: () => 6,
    };
    return build({ atlas });
  }

  function hitState(overrides = {}) {
    const participant = {
      key: "victim",
      nickname: "bob",
      avatar: "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0",
      x: 5,
      y: 5,
      pose: "standing",
      hp: 75,
      action: { kind: "hit", damage: 25, startedAt: 1000, duration: 420 },
      ...overrides,
    };
    return { participants: new Map([[participant.key, participant]]), selfKey: null, now: 1050 };
  }

  it("floats a damage number for a hit and fades it out after its lifetime", () => {
    const { ctx, renderer } = fxRenderer();
    renderer.draw(hitState());
    const texts = ctx.fillText.mock.calls.map((c) => c[0]);
    expect(texts).toContain("-25");

    // Long after the lifetime the number is gone.
    ctx.fillText.mockClear();
    renderer.draw({ ...hitState(), now: 5000 });
    expect(ctx.fillText.mock.calls.map((c) => c[0])).not.toContain("-25");
  });

  it("spawns one effect per action instance, not per frame", () => {
    const { ctx, renderer } = fxRenderer();
    renderer.draw(hitState());
    renderer.draw({ ...hitState(), now: 1100 });
    const dmgCalls = ctx.fillText.mock.calls.filter((c) => c[0] === "-25");
    // Two draws render the number twice (shadow+fill each), from ONE effect.
    expect(renderer._fx).toHaveLength(1);
    expect(dmgCalls.length).toBe(4);
  });

  it("shakes only the knocked-out player's own camera", () => {
    const { renderer } = fxRenderer();
    const ko = { kind: "ko", damage: 25, startedAt: 1000, duration: 650 };

    // Spectator: someone else got KO'd — no shake.
    renderer.draw(hitState({ action: ko, pose: "down" }));
    expect(renderer._shakeAt).toBe(null);

    // Victim: it's the local player — shake arms.
    const { renderer: mine } = fxRenderer();
    const state = hitState({ action: { ...ko, startedAt: 2000 }, pose: "down" });
    state.selfKey = "victim";
    state.now = 2010;
    mine.draw(state);
    expect(mine._shakeAt).not.toBe(null);
    expect(mine._shakeOffset(2050)).not.toBe(null);
    expect(mine._shakeOffset(2500)).toBe(null); // decayed
  });

  it("suppresses the shake under prefers-reduced-motion", () => {
    const { renderer } = fxRenderer();
    renderer._reducedMotion = true;
    const state = hitState({
      action: { kind: "ko", damage: 25, startedAt: 3000, duration: 650 },
      pose: "down",
    });
    state.selfKey = "victim";
    state.now = 3010;
    renderer.draw(state);
    expect(renderer._shakeAt).toBe(null);
  });
});

describe("Renderer in a Construct", () => {
  function seatRenderer() {
    const atlas = {
      tile: () => null,
      avatar: () => ({ canvas: {} }),
      avatarMeta: () => ({ hasIdle: true, hasSleep: true }),
      avatarFrameCount: () => 4,
    };
    return build({ atlas }).renderer;
  }

  it("seats a sitting avatar facing the way its chair does", () => {
    const renderer = seatRenderer();
    const facing = (dir) =>
      renderer._avatarPose(
        {
          key: `s-${dir}`,
          avatar: "c1.b-av.s-4.o-tun-8-6.h-0.w-adv-d-6.f-0",
          x: 3,
          y: 3,
          pose: "sitting",
          dir,
        },
        5000,
      );

    // A seat's art opens down-right as "down", and its sitter looks that way.
    expect(facing("down")).toMatchObject({ actionKind: "sleep", dir: "south-east" });
    expect(facing("right")).toMatchObject({ actionKind: "sleep", dir: "south-west" });
  });

  it("loops the dance while the pose lasts, and a wave plays over it", () => {
    const atlas = {
      tile: () => null,
      avatar: () => ({ canvas: {} }),
      avatarMeta: () => ({ hasIdle: true, hasSit: true, hasDance: true }),
      avatarFrameCount: (_recipe, kind) => (kind === "dance" ? 4 : 6),
    };
    const { renderer } = build({ atlas });
    const dancer = { key: "d", avatar: RECIPE, x: 3, y: 3, pose: "dancing", dir: "down" };
    expect(renderer._avatarPose(dancer, 5000)).toMatchObject({ actionKind: "dance", frame: 1 });
    expect(renderer._avatarPose(dancer, 5600)).toMatchObject({ actionKind: "dance", frame: 0 });
    const waving = { ...dancer, action: { kind: "wave", startedAt: 5000, duration: 840 } };
    expect(renderer._avatarPose(waving, 5420)).toMatchObject({ actionKind: "wave", frame: 3 });
  });

  it("settles a creator character into its seated clip, on the clip's last frame", () => {
    const atlas = {
      tile: () => null,
      avatar: () => ({ canvas: {} }),
      avatarMeta: () => ({ hasIdle: true, hasSit: true, hasSleep: false }),
      avatarFrameCount: (_recipe, kind) => (kind === "sit" ? 3 : 4),
    };
    const { renderer } = build({ atlas });
    const pose = renderer._avatarPose(
      { key: "s", avatar: RECIPE, x: 3, y: 3, pose: "sitting", dir: "down" },
      5000,
    );
    expect(pose).toEqual({ actionKind: "sit", dir: "south-east", frame: 2 });
  });

  it("marks the ghost's tile and the picked piece on the floor", () => {
    const { ctx, renderer } = build();
    renderer.draw({
      participants: new Map(),
      selfKey: null,
      construct: {
        ghost: { x: 2, y: 2, tile: "cst_tree", valid: false },
        selected: { x: 4, y: 4 },
      },
    });

    expect(ctx.stroke).toHaveBeenCalled();
    expect(ctx.closePath).toHaveBeenCalled();
  });
});

describe("Renderer UI kit pieces", () => {
  const KIT_IMG = { kit: true };
  const kitAtlas = () => ({
    tile: () => ({ canvas: {} }),
    avatar: () => ({ canvas: {} }),
    uiPiece: (name) =>
      ({
        nameplate: { img: KIT_IMG, x: 0, y: 0, w: 30, h: 17, t: 6, r: 10, b: 6, l: 10 },
        bubble: { img: KIT_IMG, x: 40, y: 0, w: 30, h: 30, t: 8, r: 8, b: 8, l: 8 },
        tail: { img: KIT_IMG, x: 80, y: 0, w: 11, h: 6 },
        hp: { img: KIT_IMG, x: 100, y: 0, w: 35, h: 9, t: 3, r: 3, b: 3, l: 3 },
        hp_fill: { img: KIT_IMG, x: 140, y: 0, w: 1, h: 3 },
        hp_low_fill: { img: KIT_IMG, x: 142, y: 0, w: 1, h: 3 },
      })[name] ?? null,
  });
  const alice = (extra = {}) =>
    new Map([
      [
        "registered:1",
        { key: "registered:1", nickname: "alice", x: 5, y: 5, dir: "down", ...extra },
      ],
    ]);
  const fromKit = (ctx, sx) =>
    ctx.drawImage.mock.calls.filter(([img, x]) => img === KIT_IMG && x >= sx && x < sx + 30);

  it("frames the nameplate and the bubble with the kit's art", () => {
    const { ctx, renderer } = build({ atlas: kitAtlas() });
    renderer.draw({
      participants: alice(),
      selfKey: "registered:1",
      bubbles: new Map([["registered:1", "hello"]]),
    });

    expect(fromKit(ctx, 0).length).toBeGreaterThan(0);
    expect(fromKit(ctx, 40).length).toBeGreaterThan(0);
    // Pixel text starts on a whole pixel, whatever its width.
    ctx.measureText.mockReturnValue({ width: 41 });
    renderer.draw({ participants: alice(), selfKey: "registered:1", bubbles: new Map() });
    for (const [, x] of ctx.fillText.mock.calls) expect(Number.isInteger(x)).toBe(true);
  });

  it("draws the HP bar from the kit only while the character is hurt", () => {
    const { ctx, renderer } = build({ atlas: kitAtlas() });
    renderer.draw({ participants: alice(), selfKey: "registered:1" });
    expect(fromKit(ctx, 100)).toEqual([]);

    renderer.draw({ participants: alice({ hp: 40 }), selfKey: "registered:1" });
    expect(fromKit(ctx, 100).length).toBeGreaterThan(0);
    // Below half, the amber fill.
    expect(ctx.drawImage.mock.calls.some(([img, x]) => img === KIT_IMG && x === 142)).toBe(true);
  });

  it("still writes every name and line when the kit's sheet is missing", () => {
    const { ctx, renderer } = build();
    renderer.draw({
      participants: alice({ hp: 40 }),
      selfKey: "registered:1",
      bubbles: new Map([["registered:1", "hello"]]),
    });
    const printed = ctx.fillText.mock.calls.map((c) => c[0]);
    expect(printed).toEqual(expect.arrayContaining(["alice", "hello"]));
  });
});

describe("Renderer focus prompt", () => {
  const KIT_IMG = { kit: true };
  const atlas = () => ({
    tile: () => ({ canvas: {} }),
    avatar: () => ({ canvas: {} }),
    uiPiece: (name) =>
      name === "nameplate"
        ? { img: KIT_IMG, x: 0, y: 0, w: 30, h: 17, t: 6, r: 10, b: 6, l: 10 }
        : null,
  });
  const gate = { id: "g", key: "interact", verb: "enter_construct", x: 4, y: 4, label: "Go in" };
  const texts = (ctx) => ctx.fillText.mock.calls.map(([text]) => text);

  it("names the key in front of what pressing does", () => {
    const { ctx, renderer } = build({ atlas: atlas() });
    renderer.draw({ participants: new Map(), selfKey: null, focus: gate });
    expect(texts(ctx)).toEqual(expect.arrayContaining(["E ", "Go in"]));
  });

  it("names no key where the pad is the only way to press", () => {
    const { ctx, renderer } = build({ atlas: atlas() });
    renderer.draw({ participants: new Map(), selfKey: null, focus: gate, showKeys: false });
    expect(texts(ctx)).toContain("Go in");
    expect(texts(ctx)).not.toContain("E ");
  });

  it("draws nothing without a focus", () => {
    const { ctx, renderer } = build({ atlas: atlas() });
    renderer.draw({ participants: new Map(), selfKey: null, focus: null });
    expect(texts(ctx)).toEqual([]);
  });

  it("rises above the character's own nameplate rather than over it", () => {
    const { ctx, renderer } = build({ atlas: atlas() });
    // One tile up the screen, the nameplate sits where the prompt would.
    const self = { key: "s", nickname: "alice", x: 4, y: 3, dir: "down" };
    const promptY = (participants, selfKey) => {
      ctx.fillText.mockClear();
      renderer.draw({ participants, selfKey, focus: gate, showKeys: false });
      return ctx.fillText.mock.calls.find(([text]) => text === "Go in")[2];
    };
    const alone = promptY(new Map(), null);
    const beside = promptY(new Map([["s", self]]), "s");
    const nameY = ctx.fillText.mock.calls.find(([text]) => text === "alice")[2];
    expect(beside).toBeLessThan(nameY);
    expect(beside).toBeLessThan(alone);
  });
});
