import { describe, expect, it, vi } from "vitest";

import {
  createCharacterCompositor,
  createLru,
  planFrame,
} from "../../../js/lib/space/character_compositor.js";
import { crc32 } from "../../../js/lib/space/png_palette.js";
import { CATALOG } from "./character_fixture.js";

const TUNIC = "c1.b-av.s-1.o-tun-2-3.h-lng-2.w-adv-1-0.f-0";

// The smallest PNG patchPlte accepts: a signature and a palette chunk.
function tinyPng() {
  const body = [80, 76, 84, 69, ...Array(21).fill(0)];
  const out = new Uint8Array(8 + 12 + 21);
  out.set([137, 80, 78, 71, 13, 10, 26, 10], 0);
  const view = new DataView(out.buffer);
  view.setUint32(8, 21);
  out.set(body, 12);
  view.setUint32(8 + 4 + 4 + 21, crc32(new Uint8Array(body)));
  return out;
}

function fakeCanvas(width, height, log) {
  const ctx = {
    globalCompositeOperation: "source-over",
    imageSmoothingEnabled: true,
    clearRect: () => {},
    drawImage: (img, ...args) =>
      log.push({
        canvas: `${width}x${height}`,
        img: img.name ?? img,
        op: ctx.globalCompositeOperation,
        args,
      }),
  };
  return { width, height, getContext: () => ctx };
}

function compositor(log = [], { fail = () => false, clock = { t: 0 } } = {}) {
  const fetched = [];
  const decoded = [];
  return {
    log,
    fetched,
    decoded,
    clock,
    c: createCharacterCompositor({
      catalog: CATALOG,
      fetchBytes: (url) => {
        fetched.push(url);
        return fail(url) ? Promise.reject(new Error("404")) : Promise.resolve(tinyPng());
      },
      decode: () => {
        decoded.push(1);
        return Promise.resolve({ name: `bitmap${decoded.length}`, width: 1, height: 1 });
      },
      makeCanvas: (w, h) => fakeCanvas(w, h, log),
      now: () => clock.t,
    }),
  };
}

describe("planFrame", () => {
  it("lays every piece in the frame box, overlays moved by the base's head offset", () => {
    const ops = planFrame(TUNIC, "walk", "east", 1, CATALOG);
    expect(ops.map((op) => [op.layer, op.sx, op.sy, op.dx, op.dy])).toEqual([
      // base: frame 1 of the east row (index 2), no offset of its own
      ["base-av-tun", 42, 2 * 92, 11 - 10, 24 - 20],
      // hair and hat: moved by the base's delta (+1, -1) on this frame
      ["hair-lng", 20, 2 * 30, 25 - 10 + 1, 20 - 20 - 1],
      ["hat-adv", 26, 2 * 14, 23 - 10 + 1, 16 - 20 - 1],
    ]);
  });

  it("cuts the hair with the hat's mask when a hat that hides hair is worn", () => {
    const [, hair] = planFrame(TUNIC, "walk", "south", 0, CATALOG);
    expect(hair.mask).toEqual({ layer: "hat-adv", sx: 0, sy: 0, sw: 26, sh: 18, dx: 13, dy: -8 });
    const bareHeaded = planFrame(
      "c1.b-av.s-1.o-tun-2-3.h-lng-2.w-0.f-0",
      "walk",
      "south",
      0,
      CATALOG,
    );
    expect(bareHeaded[1].mask).toBeUndefined();
  });

  it("plans nothing for a recipe, clip or facing it cannot draw", () => {
    expect(planFrame("knight", "walk", "south", 0, CATALOG)).toBeNull();
    expect(planFrame(TUNIC, "dance", "south", 0, CATALOG)).toBeNull();
    expect(planFrame(TUNIC, "walk", "up", 0, CATALOG)).toBeNull();
  });
});

describe("createLru", () => {
  it("evicts the least recently used past its byte budget, and tells", () => {
    const evicted = vi.fn();
    const lru = createLru(10, evicted);
    lru.set("a", "A", 4);
    lru.set("b", "B", 4);
    lru.get("a");
    lru.set("c", "C", 4);
    expect(lru.get("b")).toBeUndefined();
    expect(lru.get("a")).toBe("A");
    expect(evicted).toHaveBeenCalledWith("B");
    expect(lru.bytes).toBe(8);
  });

  it("keeps an entry bigger than the whole budget until the next one comes", () => {
    const lru = createLru(1);
    lru.set("big", "X", 5);
    expect(lru.get("big")).toBe("X");
  });
});

describe("createCharacterCompositor", () => {
  it("composes a strip once and hands it back after", async () => {
    const { c, fetched } = compositor();
    expect(c.strip(TUNIC, "walk", "south")).toBeNull();
    const strip = await c.prepare(TUNIC, "walk", "south");
    expect(strip).toMatchObject({ width: 50 * 2, height: 100 });
    expect(c.strip(TUNIC, "walk", "south")).toBe(strip);
    expect(fetched.sort()).toEqual(["/h-walk.png", "/m-walk.png", "/t-walk.png", "/w-walk.png"]);
  });

  it("cuts the hair on a scratch canvas before laying it on the figure", async () => {
    const { c, log } = compositor();
    await c.prepare(TUNIC, "walk", "south");
    const cut = log.filter((call) => call.canvas === "50x100");
    expect(cut.map((call) => call.op)).toEqual([
      "source-over",
      "destination-out",
      "source-over",
      "destination-out",
    ]);
  });

  it("shares a piece's download between characters and clips facing other ways", async () => {
    const { c, fetched } = compositor();
    await c.prepare(TUNIC, "walk", "south");
    await c.prepare(TUNIC, "walk", "north");
    await c.prepare("c1.b-av.s-0.o-tun-0-0.h-lng-1.w-0.f-0", "walk", "east");
    expect(fetched.filter((url) => url === "/t-walk.png")).toHaveLength(1);
  });

  it("knows where a body's head and feet are", () => {
    expect(compositor().c.bounds(TUNIC)).toEqual({ top: 6, foot: 96 });
  });

  it("decodes a piece once for every strip that needs it at the same time", async () => {
    const { c, decoded } = compositor();
    await c.prepareAll(TUNIC, ["walk"]);
    // Base, hair, hat and the hat's mask: four decodes for eight facings.
    expect(decoded).toHaveLength(4);
  });

  it("does not ask again for a piece that failed until a while has passed", async () => {
    const t = compositor([], { fail: (url) => url === "/h-walk.png" });
    expect(await t.c.prepare(TUNIC, "walk", "south")).toBeNull();
    const asked = t.fetched.length;
    await t.c.prepare(TUNIC, "walk", "south");
    expect(t.fetched).toHaveLength(asked);
    t.clock.t = 60_000;
    await t.c.prepare(TUNIC, "walk", "south");
    expect(t.fetched.length).toBeGreaterThan(asked);
  });

  it("draws the nearest strip already made while the one wanted is being made", async () => {
    const { c } = compositor();
    await c.prepare(TUNIC, "idle", "east");
    expect(c.stripOrNearest(TUNIC, "walk", "east")).toMatchObject({ anim: "idle" });
    await c.prepare(TUNIC, "walk", "east");
    expect(c.stripOrNearest(TUNIC, "walk", "east")).toMatchObject({ anim: "walk" });
  });

  it("falls back to the default character standing for somebody nothing is made of", async () => {
    const { c } = compositor();
    expect(c.stripOrNearest(TUNIC, "ko", "north")).toBeNull();
    await c.prepare(CATALOG.default, "idle", "south");
    expect(c.stripOrNearest(TUNIC, "ko", "north")).toMatchObject({ anim: "idle" });
  });
});
