import { describe, it, expect, vi, beforeEach } from "vitest";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";
import {
  drawBackground,
  drawCountdown,
  drawScanlines,
  drawWaiting,
  waitingDots,
  waitingText,
  drawCenterText,
  drawDigit,
  drawGetReady,
  drawGlitchBanner,
  drawGlitchText,
  glitchJitter,
  drawParticleDots,
  drawVignette,
  stepParticles,
} from "../../../../js/lib/games/core/render.js";

const W = 640;
const H = 480;
const colors = { bg: "#000", fg: "#0f0", muted: "#333", warning: "#fa0" };

function createMockCtx() {
  return {
    fillStyle: "",
    font: "",
    textAlign: "",
    textBaseline: "",
    shadowColor: "",
    shadowBlur: 0,
    fillRect: vi.fn(),
    fillText: vi.fn(),
    save: vi.fn(),
    restore: vi.fn(),
  };
}

describe("game hud", () => {
  let ctx;

  beforeEach(() => {
    ctx = createMockCtx();
  });

  it("fills the whole canvas with the background", () => {
    drawBackground(ctx, colors, W, H);
    expect(ctx.fillStyle).toBe(colors.bg);
    expect(ctx.fillRect).toHaveBeenCalledWith(0, 0, W, H);
  });

  it("draws one scanline every step pixels", () => {
    drawScanlines(ctx, W, H);
    expect(ctx.fillRect).toHaveBeenCalledTimes(H / 2);

    ctx = createMockCtx();
    drawScanlines(ctx, W, H, { alpha: 0.06, step: 3 });
    expect(ctx.fillRect).toHaveBeenCalledTimes(Math.ceil(H / 3));
    expect(ctx.fillStyle).toBe("rgba(0,0,0,0.06)");
  });

  it("centres the countdown number", () => {
    drawCountdown(ctx, 3, colors, 0, W, H);
    expect(ctx.fillText).toHaveBeenCalledWith("3", W / 2, H / 2);
  });

  it("waits for an opponent with animated dots", () => {
    expect(waitingDots(0)).toBe("");
    expect(waitingDots(1600)).toBe("...");
    drawWaiting(ctx, colors, 1000, W, H);
    expect(ctx.fillText).toHaveBeenCalledWith("WAITING FOR OPPONENT..", W / 2, H / 2);
  });

  it("is one message whether animated or not", () => {
    expect(waitingText()).toBe("WAITING FOR OPPONENT...");
    expect(waitingText(".")).toBe("WAITING FOR OPPONENT.");
  });

  it("reads GET READY in solo play and waits for a partner in co-op", () => {
    drawWaiting(ctx, colors, 0, W, H, { solo: true });
    expect(ctx.fillText).toHaveBeenLastCalledWith("GET READY", W / 2, H / 2);
    drawWaiting(ctx, colors, 500, W, H, { partner: true });
    expect(ctx.fillText).toHaveBeenLastCalledWith("WAITING FOR PARTNER.", W / 2, H / 2);
  });
});

describe("the frame pieces the games share", () => {
  const canvas = () => recordingCanvas(640, 480);

  it("drawVignette darkens the edges with a radial gradient, sized by height or width", () => {
    const c = canvas();
    const ctx = c.getContext("2d");
    drawVignette(ctx, 640, 480);
    drawVignette(ctx, 640, 480, { from: 0.3, to: 0.7, of: "width", edge: 0.3 });
    expect(
      c.log.filter(([op]) => op.startsWith("createRadialGradient") || op.endsWith("addColorStop")),
    ).toEqual([
      ["createRadialGradient", 320, 240, 192, 320, 240, 384],
      ["g1.addColorStop", 0, "rgba(0,0,0,0)"],
      ["g1.addColorStop", 1, "rgba(0,0,0,0.4)"],
      ["createRadialGradient", 320, 240, 192, 320, 240, 448],
      ["g2.addColorStop", 0, "rgba(0,0,0,0)"],
      ["g2.addColorStop", 1, "rgba(0,0,0,0.3)"],
    ]);
    expect(c.log.filter(([op]) => op === "fillRect")).toEqual([
      ["fillRect", 0, 0, 640, 480],
      ["fillRect", 0, 0, 640, 480],
    ]);
  });

  it("drawDigit lights the pixels of a 5x7 bitmap digit, and nothing for a non-digit", () => {
    const c = canvas();
    const ctx = c.getContext("2d");
    drawDigit(ctx, 1, 10, 20, 4);
    // 1: .x... / xx... / .x... ×4 / xxx.. → 10 pixels lit
    const lit = c.log.filter(([op]) => op === "fillRect");
    expect(lit).toHaveLength(10);
    expect(lit[0]).toEqual(["fillRect", 18, 20, 4, 4]);
    c.log.length = 0;
    drawDigit(ctx, 12, 0, 0, 4);
    expect(c.log.filter(([op]) => op === "fillRect")).toEqual([]);
  });

  it("drawCenterText writes bold monospace text at the centre, lowered by an offset", () => {
    const c = canvas();
    const ctx = c.getContext("2d");
    drawCenterText(ctx, "KO!", 48, "red", 640, 480);
    drawCenterText(ctx, "P1 WINS", 28, "blue", 640, 480, 30);
    expect(c.log.filter(([op]) => op === "fillText")).toEqual([
      ["fillText", "KO!", 320, 240],
      ["fillText", "P1 WINS", 320, 270],
    ]);
    expect(c.log).toContainEqual(["font", "=", "bold 48px monospace"]);
  });

  it("drawGetReady flickers GET READY at the centre", () => {
    const c = canvas();
    drawGetReady(c.getContext("2d"), { fg: "cyan" }, 0, 640, 480);
    expect(c.log.filter(([op]) => op === "fillText")).toEqual([
      ["fillText", "GET READY", 320, 240],
    ]);
  });

  it("drawParticleDots draws each particle as a dot fading with its life", () => {
    const c = canvas();
    drawParticleDots(c.getContext("2d"), [
      { x: 10, y: 10, life: 0.5, color: "red" },
      { x: 0, y: 0, life: 1 },
    ]);
    expect(c.log.filter(([op]) => op === "fillRect")).toEqual([
      ["fillRect", 8, 8, 4, 4],
      ["fillRect", -2, -2, 4, 4],
    ]);
    expect(c.log).toContainEqual(["globalAlpha", "=", 0.5]);
  });

  it("stepParticles moves, slows and fades particles, dropping the spent ones", () => {
    const next = stepParticles(
      [
        { x: 0, y: 0, vx: 10, vy: -10, life: 1, tag: "a" },
        { x: 0, y: 0, vx: 1, vy: 1, life: 0.03 },
      ],
      { drag: 0.96, fade: 0.04 },
    );
    expect(next).toEqual([{ x: 10, y: -10, vx: 9.6, vy: -9.6, life: 0.96, tag: "a" }]);
  });
});

describe("glitched text", () => {
  it("glitchJitter shifts now and then: it draws for the y shift only when it has one", () => {
    const draws = [0.95, 0.75, 0.5];
    const random = () => draws.shift();
    expect(glitchJitter(random)).toEqual([1, 0]);
    expect(draws).toEqual([]);

    const calm = [0.5, 0.5];
    expect(glitchJitter(() => calm.shift())).toEqual([0, 0]);

    const xOnly = [0.95, 0.75, 0.99];
    expect(glitchJitter(() => xOnly.shift(), { over: 0.85, y: 0 })).toEqual([1, 0]);
    expect(xOnly).toEqual([0.99]);
  });

  it("drawGlitchText draws red and blue copies apart, then the text in its colour", () => {
    const c = recordingCanvas(640, 480);
    drawGlitchText(c.getContext("2d"), "WIN", 320, 240, "cyan", { offset: [1, -1] });
    expect(c.log.filter(([op]) => op === "fillText")).toEqual([
      ["fillText", "WIN", 319, 239],
      ["fillText", "WIN", 323, 239],
      ["fillText", "WIN", 320, 240],
    ]);
    expect(c.log).toContainEqual(["globalAlpha", "=", 0.5]);
    expect(c.log).toContainEqual(["shadowBlur", "=", 20]);
  });

  it("drawGlitchBanner glitches the title in the middle and pulses the line under it", () => {
    const c = recordingCanvas(640, 480);
    vi.spyOn(Math, "random").mockReturnValue(0.5);
    drawGlitchBanner(
      c.getContext("2d"),
      {
        text: "P1 WINS!",
        color: "cyan",
        sub: "3 - 1",
        subFont: "18px monospace",
        subColor: "gold",
      },
      0,
      640,
      480,
    );
    expect(c.log.filter(([op]) => op === "fillText").map(([, text, x, y]) => [text, x, y])).toEqual(
      [
        ["P1 WINS!", 318, 240],
        ["P1 WINS!", 322, 240],
        ["P1 WINS!", 320, 240],
        ["3 - 1", 320, 280],
      ],
    );
    expect(c.log).toContainEqual(["font", "=", "bold 36px monospace"]);
    expect(c.log).toContainEqual(["font", "=", "18px monospace"]);
    expect(c.log).toContainEqual(["globalAlpha", "=", 0.5]);
    vi.restoreAllMocks();
  });

  it("drawGlitchBanner draws only the title when there is no line", () => {
    const c = recordingCanvas(640, 480);
    drawGlitchBanner(c.getContext("2d"), { text: "DRAW", color: "cyan", size: 32 }, 0, 640, 480);
    expect(c.log.filter(([op]) => op === "fillText")).toHaveLength(3);
    expect(c.log).toContainEqual(["font", "=", "bold 32px monospace"]);
  });
});
