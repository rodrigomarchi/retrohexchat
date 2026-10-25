import { describe, it, expect, afterEach, vi } from "vitest";
import { loadP2PEngineClass } from "../../../js/lib/games/engine_loader.js";
import { playMatch } from "../../support/games/harness.js";

// One id per engine: the variants share their engine's lifecycle.
const GAMES = [
  "hex_pong",
  "block_breakers",
  "light_trails",
  "star_duel",
  "hex_warlords",
  "pixel_tanks",
  "hex_raid",
  "hex_boxing",
  "hex_outlaw",
  "hex_invaders",
  "hex_enduro",
  "hex_tennis",
  "hex_skiing",
  "hex_frost",
  "hex_hockey",
];

describe.each(GAMES)("%s when the other side disconnects", (gameId) => {
  let match;

  afterEach(() => {
    match?.stop();
    match?.restore();
    match = null;
  });

  it("ends a match in play, redraws it once and reports it as disconnected", async () => {
    const Engine = await loadP2PEngineClass(gameId);
    match = await playMatch({ gameId });
    match.advance(5000);
    const { host } = match.engines;
    expect(host.gameState.phase).not.toBe(Engine.FINAL_PHASE);

    // The engine repaints in the frame after the close; the harness notices
    // the new phase only after that paint and would wipe it, so the log is
    // kept whole while the frame is watched.
    const canvas = match.canvases.host;
    canvas.clearLog();
    canvas.recording = true;
    vi.spyOn(canvas, "clearLog").mockImplementation(() => {});
    match.close();
    match.advance(50);

    expect(host.gameState.phase).toBe(Engine.FINAL_PHASE);
    expect(canvas.log.length).toBeGreaterThan(0);
    expect(match.results.host).toEqual([expect.objectContaining({ disconnected: true })]);
  });

  it("stays over afterwards: no countdown, step or second report", async () => {
    const Engine = await loadP2PEngineClass(gameId);
    match = await playMatch({ gameId });
    match.advance(2000);
    match.close();
    match.advance(100);
    const phases = match.record().phases.length;

    match.advance(10_000);

    expect(match.engines.host.gameState.phase).toBe(Engine.FINAL_PHASE);
    expect(match.record().phases.length).toBe(phases);
    expect(match.results.host).toHaveLength(1);
  });

  it("does not throw before the first state arrives", async () => {
    match = await playMatch({ gameId });
    expect(() => match.close()).not.toThrow();
  });
});
