import { describe, expect, it } from "vitest";
import { PHASE } from "../../../../js/lib/games/core/solo/phases.js";
import HexBlocks from "../../../../js/lib/games/hex_blocks/index.js";
import { COLS, COUNTDOWN_TICKS, ROWS } from "../../../../js/lib/games/hex_blocks/protocol.js";
import { cellsOf, filled, landing } from "../../../../js/lib/games/hex_blocks/rules.js";
import { soloMatches } from "../../../support/games/solo_tests.js";

const DESKTOP = { left: 0, top: 0, width: 640, height: 480 };
const PHONE = { left: 0, top: 0, width: 400, height: 484 };
const solo = soloMatches(HexBlocks, "hex_blocks", DESKTOP);
/** A match with its count over: the first piece falling. */
async function ready(options) {
  const match = await solo(options);
  expect(match.runUntil(() => match.engines.host.gameState.piece !== null, 5_000)).toBe(true);
  return match;
}

describe("a match of Hex Blocks", () => {
  it("counts three seconds down, then brings the first piece in", async () => {
    const match = await solo();
    const { host } = match.engines;
    match.advance(1000);
    expect(host.gameState.piece).toBeNull();
    expect(host.gameState.phase).toBe(PHASE.PLAYING);
    expect(match.runUntil(() => host.gameState.piece !== null, 5_000)).toBe(true);
    expect(host.gameState.clock.started).toBe(true);
    expect(host.gameState.countdown).toBe(0);
    expect(COUNTDOWN_TICKS).toBe(180);
  });

  it("moves with the arrows, and drops with the space bar", async () => {
    const match = await ready();
    const { host } = match.engines;
    const c0 = host.gameState.piece.c;
    match.key("host", "ArrowLeft");
    match.key("host", "ArrowLeft", "keyup");
    match.advance(20);
    expect(host.gameState.piece.c).toBe(c0 - 1);
    const landed = landing(host.gameState.well, host.gameState.piece);
    match.key("host", " ");
    match.advance(20);
    expect(filled(host.gameState.well)).toBe(4);
    for (const [c, r] of cellsOf(landed)) {
      expect(host.gameState.well.cells[r * COLS + c]).not.toBe(0);
    }
  });

  it("repeats a move while its key is held, and stops when it comes up", async () => {
    const match = await ready();
    const { host } = match.engines;
    match.key("host", "ArrowRight");
    match.advance(400);
    const right = host.gameState.piece.c;
    // Held long enough, against the right wall.
    expect(Math.max(...cellsOf(host.gameState.piece).map(([c]) => c))).toBe(COLS - 1);
    match.key("host", "ArrowRight", "keyup");
    match.key("host", "ArrowLeft");
    match.key("host", "ArrowLeft", "keyup");
    match.advance(300);
    expect(host.gameState.piece.c).toBe(right - 1);
  });

  it("takes no press on its canvas: the keys are the pad's, under the game", async () => {
    const match = await ready({ rect: PHONE });
    const { host } = match.engines;
    const before = host.gameState.piece;
    match.tap(200, 300);
    match.advance(20);
    expect(host.gameState.piece.c).toBe(before.c);
    expect(host.gameState.piece.turn).toBe(before.turn);
  });

  it("lets go of a held move when the window loses the keyboard", async () => {
    const match = await ready();
    const { host } = match.engines;
    match.key("host", "ArrowDown");
    match.advance(50);
    expect(host.gameState.inputs.down).toBe(true);
    window.dispatchEvent(new Event("blur"));
    match.advance(20);
    expect(host.gameState.inputs.down).toBe(false);
  });

  it("ends with the stack over the top, scoring the points it had", async () => {
    const match = await ready();
    const { host } = match.engines;
    const cells = [...host.gameState.well.cells];
    for (let r = 2; r < ROWS; r++) for (let c = 1; c < COLS; c++) cells[r * COLS + c] = 1;
    host.gameState = { ...host.gameState, well: { cells }, score: 4321 };
    match.key("host", " ");
    expect(match.runUntil(() => match.over(), 10_000)).toBe(true);
    expect(match.results.host[0].score.p1).toBeGreaterThanOrEqual(4321);
    expect(match.results.host[0].ended_early).toBeFalsy();
  });

  it("ends early with the points it has", async () => {
    const match = await ready();
    match.engines.host.gameState = { ...match.engines.host.gameState, score: 900 };
    match.engines.host.quit();
    expect(match.results.host).toEqual([{ score: { p1: 900, p2: 0 }, ended_early: true }]);
  });

  it("deals the same pieces for the same seed, and plays the Sprint by its own rules", async () => {
    const queue = async (options) => {
      const m = await ready(options);
      const { piece, queue: next, mode } = m.engines.host.gameState;
      m.stop();
      m.restore();
      return { kinds: [piece.kind, ...next.slice(0, 3)], mode };
    };
    expect((await queue()).kinds).toEqual((await queue()).kinds);
    expect((await queue()).kinds).not.toEqual((await queue({ matchSeed: 43 })).kinds);
    expect((await queue({ gameId: "hex_blocks_sprint" })).mode).toEqual({ sprint: true, goal: 40 });
  });

  it("stands the table up on a phone held upright", async () => {
    const match = await ready({ rect: PHONE });
    const { laid } = match.engines.host;
    expect(laid.view).toEqual({ width: 400, height: 484 });
    expect(laid.well.y).toBeGreaterThan(laid.hold.y + laid.hold.h);
  });
});
