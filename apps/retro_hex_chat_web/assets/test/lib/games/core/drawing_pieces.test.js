import { describe, expect, it } from "vitest";
import {
  GREEN_ON_BLACK,
  drawRoundDots,
  drawScoreLabels,
  drawShotDot,
  drawShotTrail,
  drawSquareParticles,
  drawTopLabel,
  stepParticles,
} from "../../../../js/lib/games/core/render.js";
import {
  FANFARE,
  LOSE_SWEEP,
  WIN_FANFARE,
  fade,
  notes,
  ring,
  sweep,
} from "../../../../js/lib/games/core/synth.js";
import { flags, schema } from "../../../../js/lib/games/core/codec.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";

const COLORS = { fg: "#0f0", accent: "#0ff", muted: "#333" };
const drawn = (draw) => {
  const canvas = recordingCanvas(640, 480);
  const ctx = canvas.getContext("2d");
  draw(ctx);
  return canvas.log;
};

describe("the duels' chrome", () => {
  it("drawScoreLabels writes player one's points left and player two's right", () => {
    const log = drawn((ctx) => drawScoreLabels(ctx, { score1: 3, score2: 4 }, COLORS, 4, 636, 10));
    expect(log).toContainEqual(["fillText", "P1: 3", 4, 10]);
    expect(log).toContainEqual(["fillText", "P2: 4", 636, 10]);
  });

  it("drawRoundDots lights a dot for each round a side took", () => {
    const log = drawn((ctx) =>
      drawRoundDots(ctx, { roundWins1: 1, roundWins2: 2 }, COLORS, 640, 20),
    );
    const fills = log.filter(([op]) => op === "fillStyle").map(([, , color]) => color);
    expect(fills).toEqual(["#0f0", "#333", "#333", "#0ff", "#0ff", "#333"]);
  });

  it("drawTopLabel centres its text at the top in its colour", () => {
    const log = drawn((ctx) => drawTopLabel(ctx, "ROUND 2", "#333", 640, 6));
    expect(log).toContainEqual(["fillText", "ROUND 2", 320, 6]);
    expect(log).toContainEqual(["fillStyle", "=", "#333"]);
  });

  it("GREEN_ON_BLACK reads the page's colours with the sports games' fallbacks", () => {
    expect(GREEN_ON_BLACK.fg).toEqual(["--game-fg-color", "39ff14"]);
  });
});

describe("shots and particles", () => {
  it("drawShotTrail leaves three fading dots behind the way a shot flies", () => {
    const log = drawn((ctx) => drawShotTrail(ctx, 100, 100, 0, -1, 3, "#fff"));
    const arcs = log.filter(([op]) => op === "arc").map(([, x, y]) => [x, y]);
    expect(arcs).toEqual([
      [100, 104],
      [100, 108],
      [100, 112],
    ]);
  });

  it("drawShotDot draws the shot and a core half its size", () => {
    const log = drawn((ctx) => drawShotDot(ctx, 5, 6, 4, "#f00", "#fff"));
    const radii = log.filter(([op]) => op === "arc").map((call) => call[3]);
    expect(radii).toEqual([4, 2]);
  });

  it("drawSquareParticles draws each in its own colour, size and fade", () => {
    const log = drawn((ctx) =>
      drawSquareParticles(ctx, [{ x: 10, y: 10, life: 0.5 }], (p) => ({
        alpha: p.life,
        color: "#abc",
        size: 4,
      })),
    );
    expect(log).toEqual([
      ["globalAlpha", "=", 0.5],
      ["fillStyle", "=", "#abc"],
      ["fillRect", 8, 8, 4, 4],
      ["globalAlpha", "=", 1],
    ]);
  });

  it("stepParticles moves particles by a game's own velocity when it gives one", () => {
    const [p] = stepParticles([{ x: 0, y: 0, vx: 2, vy: 1, life: 2 }], {
      fade: 1,
      velocity: (q) => ({ vx: q.vx, vy: q.vy + 1 }),
    });
    expect(p).toMatchObject({ x: 2, y: 1, vx: 2, vy: 2, life: 1 });
  });
});

describe("shared sounds", () => {
  it("ring is a steady note that fades exponentially", () => {
    expect(ring("sine", 440, 0.2, 0.1)).toEqual({
      wave: "sine",
      freq: 440,
      vol: fade(0.1, 0.2, "exp"),
      dur: 0.2,
    });
  });

  it("WIN_FANFARE and LOSE_SWEEP are the duels' end of a match", () => {
    expect(WIN_FANFARE).toEqual(notes(FANFARE, { wave: "square", note: 0.12, vol: 0.12 }));
    expect(LOSE_SWEEP).toEqual(sweep("sawtooth", 500, 150, 0.7, 0.1));
  });
});

describe("flags", () => {
  it("writes anything truthy as a set bit and reads it back as true", () => {
    const wire = schema(1, [flags(["a", "b", "c"])]);
    expect(wire.decode(wire.encode({ a: 2, b: 0, c: "yes" }))).toEqual({
      a: true,
      b: false,
      c: true,
    });
  });
});
