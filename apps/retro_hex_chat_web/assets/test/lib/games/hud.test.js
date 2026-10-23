import { describe, it, expect, vi, beforeEach } from "vitest";
import {
  drawBackground,
  drawCountdown,
  drawScanlines,
  drawWaiting,
  waitingDots,
  waitingText,
} from "../../../js/lib/games/hud.js";

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
