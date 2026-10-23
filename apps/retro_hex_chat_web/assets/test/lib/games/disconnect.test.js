import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { startMatch } from "../../helpers/game_match.js";
import { loadP2PEngineClass } from "../../../js/lib/games/engine_loader.js";

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

function closeChannel(channel) {
  for (const fn of [...channel._listeners.close]) fn({});
}

describe.each(GAMES)("%s when the other side disconnects", (gameId) => {
  let match;
  let Engine;

  beforeEach(async () => {
    vi.useFakeTimers();
    Engine = await loadP2PEngineClass(gameId);
  });

  afterEach(() => {
    match?.stop();
    match = null;
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it("ends a match in play, redraws it and reports it as disconnected", () => {
    match = startMatch(Engine, gameId);
    match.advance(300);
    const { host } = match;
    expect(host.gameState).toBeTruthy();
    host.gameState.phase = 1;
    host._renderPending = false;

    closeChannel(match.hostChannel);

    expect(host.gameState.phase).toBe(Engine.FINAL_PHASE);
    expect(host._renderPending).toBe(true);
    expect(match.results.host.at(-1)).toMatchObject({ disconnected: true });
  });

  it("never lets a pending countdown fire afterwards", () => {
    match = startMatch(Engine, gameId);
    match.advance(300);
    const { host } = match;
    host.gameState.phase = 1;
    const tick = vi.fn();
    host._clearPhaseTimer();
    host.phaseTimer = setTimeout(tick, 1000);

    closeChannel(match.hostChannel);
    vi.advanceTimersByTime(5000);

    expect(tick).not.toHaveBeenCalled();
    expect(host.phaseTimer).toBeNull();
  });

  it("does not throw before the first state arrives", () => {
    match = startMatch(Engine, gameId);
    match.guest.gameState = null;
    expect(() => closeChannel(match.guestChannel)).not.toThrow();
  });
});
