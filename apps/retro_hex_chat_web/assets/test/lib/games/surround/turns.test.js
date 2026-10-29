import { describe, expect, it } from "vitest";

import { DIR, PHASE } from "../../../../js/lib/games/surround/protocol.js";
import { matchPerTest } from "../../../support/games/harness.js";

/*
 * The grid moves ten times a second, and a player who turns twice inside one
 * move — up, then left, to double back — expects both turns. The second one
 * waits for the move after the first.
 */

let match = null;

const startMatch = matchPerTest();

async function playing() {
  match = await startMatch({ gameId: "light_trails", mode: "p2p", seed: 2, matchSeed: 5 });
  const reached = match.runUntil(
    () => match.engines.host.gameState?.phase === PHASE.PLAYING,
    30_000,
  );
  expect(reached).toBe(true);
}

/**
 * Where a side's cycle was, and where it is after `keys` are pressed on that
 * side and `ms` go by.
 * @param {"host"|"guest"} side - the host steers player one, the guest player two
 */
function turnsOf(side, keys, ms) {
  const cycle = () => match.engines.host.gameState[side === "host" ? "p1" : "p2"];
  const start = { ...cycle() };
  for (const key of keys) match.key(side, key);
  match.advance(ms);
  return { start, end: cycle() };
}

describe("Light Trails — two turns inside one grid move", () => {
  it("makes both of the host's turns, one move after the other", async () => {
    await playing();
    const { start, end } = turnsOf("host", ["ArrowUp", "ArrowLeft"], 250);

    expect(start.dir).toBe(DIR.RIGHT);
    expect(end.dir).toBe(DIR.LEFT);
    expect(end.y).toBe(start.y - 1);
    expect(end.x).toBeLessThan(start.x);
  });

  it("makes both of the guest's turns too", async () => {
    await playing();
    const { start, end } = turnsOf("guest", ["ArrowDown", "ArrowRight"], 300);

    expect(start.dir).toBe(DIR.LEFT);
    expect(end.dir).toBe(DIR.RIGHT);
    expect(end.y).toBe(start.y + 1);
  });

  it("still ignores a lone turn straight back", async () => {
    await playing();
    const { start, end } = turnsOf("host", ["ArrowLeft"], 250);

    expect(end.dir).toBe(DIR.RIGHT);
    expect(end.y).toBe(start.y);
  });
});
