import { describe, expect, it } from "vitest";
import {
  GROUND_Y,
  PHASE,
  UNDER_Y,
  VINE_HANG_Y,
} from "../../../../js/lib/games/hex_jungle/protocol.js";
import {
  createInitialState,
  logsFor,
  respawn,
  vineX,
} from "../../../../js/lib/games/hex_jungle/physics.js";
import { hud, layout, readColors, render } from "../../../../js/lib/games/hex_jungle/renderer.js";
import * as SPRITES from "../../../../js/lib/games/hex_jungle/sprites.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";

const screenOf = (scene, object) => (scene << 3) | object;
const on = (screen, rest = {}, player = {}) => {
  const state = createInitialState();
  return {
    ...state,
    phase: PHASE.PLAYING,
    screen,
    logs: logsFor(screen),
    ...rest,
    player: { ...state.player, ...player },
  };
};
const kinds = (state) => layout(state).map((shape) => shape.kind);
const shapesOf = (state, kind) => layout(state).filter((shape) => shape.kind === kind);

describe("what a screen shows", () => {
  it("a ladder screen: its hole, the ladder, and a wall in the tunnel on the side bit 7 names", () => {
    expect(shapesOf(on(screenOf(0, 6)), "hole")).toEqual([
      expect.objectContaining({ x: 72, w: 8 }),
    ]);
    expect(kinds(on(screenOf(0, 6)))).toContain("ladder");
    expect(shapesOf(on(screenOf(0, 6)), "wall")).toEqual([expect.objectContaining({ x: 17 })]);
    expect(shapesOf(on(0b10000110), "wall")).toEqual([expect.objectContaining({ x: 136 })]);
    expect(shapesOf(on(screenOf(1, 6)), "hole")).toHaveLength(3);
  });

  it("a pit, as wide as it is open now", () => {
    expect(shapesOf(on(screenOf(2, 6)), "pit")).toEqual([
      expect.objectContaining({ x: 44, w: 64, liquid: "tar" }),
    ]);
    expect(shapesOf(on(screenOf(6, 6), { tick: 12 }), "pit")).toEqual([
      expect.objectContaining({ x: 44 + 16, w: 64 - 32 }),
    ]);
    expect(shapesOf(on(screenOf(6, 6), { tick: 100 }), "pit")).toEqual([]);
    expect(shapesOf(on(screenOf(7, 6)), "pit")[0].liquid).toBe("quicksand");
  });

  it("three crocodiles, their jaws as the clock has them", () => {
    const shut = shapesOf(on(screenOf(4, 0), { tick: 10 }), "crocodile");
    expect(shut.map((c) => c.x)).toEqual([60, 76, 92]);
    expect(shut.every((c) => c.open === false)).toBe(true);
    expect(shapesOf(on(screenOf(4, 0), { tick: 200 }), "crocodile")[0].open).toBe(true);
  });

  it("the vine where it swings, only on a screen with one", () => {
    const [vine] = shapesOf(on(screenOf(2, 6), { tick: 142 }), "vine");
    expect(vine).toMatchObject({ x: vineX(142), y: VINE_HANG_Y - 22 });
    expect(shapesOf(on(screenOf(0, 6)), "vine")).toEqual([]);
  });

  it("logs where they are, fire or a snake at x 124, a treasure only while it lies", () => {
    expect(shapesOf(on(screenOf(0, 3)), "log").map((l) => l.x)).toEqual([124, 140, 156]);
    expect(shapesOf(on(screenOf(0, 6)), "fire")).toEqual([expect.objectContaining({ x: 124 })]);
    expect(shapesOf(on(screenOf(0, 7)), "snake")).toEqual([expect.objectContaining({ x: 124 })]);
    expect(shapesOf(on(screenOf(5, 2)), "treasure")).toEqual([
      expect.objectContaining({ x: 124, treasure: "gold" }),
    ]);
    expect(shapesOf(on(screenOf(5, 2), { taken: 0xffffffff }), "treasure")).toEqual([]);
  });

  it("a scorpion in a tunnel without a ladder", () => {
    expect(shapesOf(on(screenOf(2, 0), { scorpionX: 70 }), "scorpion")).toEqual([
      expect.objectContaining({ x: 70, y: UNDER_Y - 8 }),
    ]);
    expect(shapesOf(on(screenOf(0, 0)), "scorpion")).toEqual([]);
  });

  it("the player, in the pose they are in", () => {
    const pose = (player, rest) => shapesOf(on(screenOf(0, 6), rest, player), "player")[0].pose;
    expect(pose({})).toBe("stand");
    expect(pose({ jumpTick: 5 })).toBe("jump");
    expect(pose({ climbing: true })).toBe("climb");
    expect(pose({ onVine: true })).toBe("hang");
    expect(pose({ kneeling: "rolling" })).toBe("kneel");
    expect(shapesOf(on(screenOf(0, 6)), "player")[0]).toMatchObject({ x: 18, y: GROUND_Y - 22 });
  });

  it("the player blinks while dying, every 6 frames", () => {
    const dying = on(screenOf(0, 6), { phase: PHASE.DYING });
    const shown = [0, 6, 12, 18].map(
      (frame) => layout(dying, frame).filter((s) => s.kind === "player").length,
    );
    expect(shown).toEqual([1, 0, 1, 0]);
    expect(layout(on(screenOf(0, 6)), 6).filter((s) => s.kind === "player")).toHaveLength(1);
  });
});

describe("the top line", () => {
  it("shows the points, the time left as minutes and seconds, and the spare lives", () => {
    expect(hud(createInitialState())).toEqual({ score: "2000", time: "20:00", spare: 2 });
    expect(hud({ ...createInitialState(), timerTicks: 61 * 60 + 59, lives: 1, score: 7 })).toEqual({
      score: "7",
      time: "01:01",
      spare: 0,
    });
  });
});

describe("painting", () => {
  const colors = readColors(document.createElement("canvas"));

  it("paints every screen of the ring, above and below, in every phase, without failing", () => {
    for (let screen = 1; screen < 256; screen++) {
      for (const rest of [{}, { underground: true }, { phase: PHASE.DYING }]) {
        const canvas = recordingCanvas(640, 480);
        canvas.recording = false;
        expect(() => render(canvas.getContext("2d"), on(screen, rest), colors, 0)).not.toThrow();
      }
    }
    const canvas = recordingCanvas(640, 480);
    expect(() => render(canvas.getContext("2d"), respawn(on(1)), colors, 0)).not.toThrow();
  });

  it("scales the cartridge's 160 pixels to the canvas: the ladder's hole at x 288, 32 wide", () => {
    const canvas = recordingCanvas(640, 480);
    canvas.recording = true;
    render(canvas.getContext("2d"), on(screenOf(0, 6)), colors, 0);
    const fills = canvas.log.filter((e) => e[0] === "fillRect");
    expect(fills.some(([, x, , w]) => x === 288 && w === 32)).toBe(true);
  });
});

describe("the sprites", () => {
  const sizes = (rows) => [rows[0].length, rows.length];
  const square = (rows) => rows.every((row) => row.length === rows[0].length);

  it("draw the explorer 8 wide and 22 tall in every pose", () => {
    for (const rows of Object.values(SPRITES.EXPLORER)) {
      expect(sizes(rows)).toEqual([8, 22]);
      expect(square(rows)).toBe(true);
    }
  });

  it("keep every row of a sprite the same width", () => {
    const all = [
      SPRITES.LOG,
      SPRITES.SNAKE,
      SPRITES.SCORPION,
      ...SPRITES.FIRE,
      ...Object.values(SPRITES.CROCODILE),
      ...Object.values(SPRITES.TREASURES),
    ];
    for (const rows of all) expect(square(rows) && rows[0].length === 8).toBe(true);
  });

  it("keep the jungle below the top line: a player dropping back in never covers the points", () => {
    const canvas = recordingCanvas(640, 480);
    canvas.recording = true;
    render(canvas.getContext("2d"), respawn(on(screenOf(3, 1))), readColors(canvas), 0);
    const ops = canvas.log.map((entry) => entry[0]);
    const clipAt = ops.indexOf("clip");
    expect(clipAt).toBeGreaterThan(-1);
    expect(canvas.log.find((entry) => entry[0] === "rect")).toEqual(["rect", 0, 60, 640, 420]);
    expect(ops.lastIndexOf("restore")).toBeGreaterThan(clipAt);
  });

  it("draw the top line inside the canvas", () => {
    const canvas = recordingCanvas(640, 480);
    canvas.recording = true;
    render(canvas.getContext("2d"), on(screenOf(0, 6)), readColors(canvas), 0);
    const fills = canvas.log.filter((e) => e[0] === "fillRect");
    expect(fills.every(([, , y]) => y >= 0)).toBe(true);
  });
});
