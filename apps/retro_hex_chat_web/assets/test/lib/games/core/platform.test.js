import { describe, expect, it } from "vitest";
import {
  cadence,
  climbStep,
  edgeExit,
  fall,
  jumpStep,
  ladderGrab,
  overlaps,
} from "../../../../js/lib/games/core/platform.js";

// A jump as a table of lines moved each tick, up positive: this one rises 10
// lines over 16 ticks and comes back down over the next 16.
const RISE = [1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1];
const DROP = [-1, 0, 0, 0, -1, 0, 0, -1, 0, -1, -1, -1, -1, -1, -1, -1];
const JUMP = [...RISE, ...DROP];

const jump = (body, ticks) => {
  let current = body;
  for (let i = 0; i < ticks; i++) current = jumpStep(current, JUMP);
  return current;
};

describe("cadence", () => {
  it("fires once every so many ticks, from the first", () => {
    const fired = (every) => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].filter((t) => cadence(t, every));
    expect(fired(1)).toEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    expect(fired(2)).toEqual([0, 2, 4, 6, 8]);
    expect(fired(8)).toEqual([0, 8]);
  });
});

describe("jumpStep", () => {
  const standing = { x: 20, y: 32, jumpTick: 0 };

  it("follows the table: up while it rises, back where it left once it is done", () => {
    expect(jump(standing, 16).y).toBe(22);
    expect(Math.min(...[...Array(33).keys()].map((t) => jump(standing, t).y))).toBe(22);
    const landed = jump(standing, 32);
    expect(landed.y).toBe(32);
    expect(landed.jumpTick).toBe(32);
  });

  it("says when the table has run out, and moves nothing after it", () => {
    expect(jump(standing, 31).jumpTick < JUMP.length).toBe(true);
    const done = jump(standing, 32);
    expect(jumpStep(done, JUMP)).toBe(done);
  });
});

describe("fall", () => {
  it("drops a line a tick and stops exactly on the floor", () => {
    let body = { x: 0, y: 28 };
    const seen = [];
    for (let i = 0; i < 6; i++) {
      body = fall(body, 32);
      seen.push(body.y);
    }
    expect(seen).toEqual([29, 30, 31, 32, 32, 32]);
  });

  it("falls faster when told, never past the floor", () => {
    expect(fall({ y: 30 }, 32, 4).y).toBe(32);
    expect(fall({ y: 20 }, 32, 4).y).toBe(24);
  });
});

describe("ladderGrab", () => {
  const ladder = { left: 68, right: 82, x: 76 };

  it("snaps to the ladder's line from anywhere in its reach", () => {
    expect(ladderGrab(68, ladder)).toBe(76);
    expect(ladderGrab(82, ladder)).toBe(76);
    expect(ladderGrab(75, ladder)).toBe(76);
  });

  it("is out of reach a pixel either side", () => {
    expect(ladderGrab(67, ladder)).toBeNull();
    expect(ladderGrab(83, ladder)).toBeNull();
  });
});

describe("climbStep", () => {
  const ladder = { top: 32, bottom: 86, rung: 5, every: 8 };

  it("moves a rung every so many ticks, in the direction held", () => {
    expect(climbStep({ y: 50 }, ladder, 1, 0).y).toBe(55);
    expect(climbStep({ y: 50 }, ladder, 1, 3).y).toBe(50);
    expect(climbStep({ y: 50 }, ladder, -1, 8).y).toBe(45);
    expect(climbStep({ y: 50 }, ladder, 0, 8).y).toBe(50);
  });

  it("stops at the top and at the bottom", () => {
    expect(climbStep({ y: 34 }, ladder, -1, 0).y).toBe(32);
    expect(climbStep({ y: 84 }, ladder, 1, 0).y).toBe(86);
    expect(climbStep({ y: 86 }, ladder, 1, 0).y).toBe(86);
  });
});

describe("overlaps", () => {
  const box = { x: 10, y: 10, w: 8, h: 8 };

  it("is true with a pixel in common", () => {
    expect(overlaps(box, { x: 17, y: 17, w: 8, h: 8 })).toBe(true);
    expect(overlaps(box, { x: 12, y: 12, w: 2, h: 2 })).toBe(true);
  });

  it("is false for boxes that only touch, or are apart", () => {
    expect(overlaps(box, { x: 18, y: 10, w: 8, h: 8 })).toBe(false);
    expect(overlaps(box, { x: 10, y: 18, w: 8, h: 8 })).toBe(false);
    expect(overlaps(box, { x: 40, y: 40, w: 8, h: 8 })).toBe(false);
  });
});

describe("edgeExit", () => {
  it("says which edge a position went out by", () => {
    expect(edgeExit(7, 8, 148)).toBe(-1);
    expect(edgeExit(149, 8, 148)).toBe(1);
    expect(edgeExit(8, 8, 148)).toBe(0);
    expect(edgeExit(148, 8, 148)).toBe(0);
  });
});
