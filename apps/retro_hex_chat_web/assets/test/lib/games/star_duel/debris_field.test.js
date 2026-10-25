import { describe, it, expect, afterEach } from "vitest";
import { PHASE } from "../../../../js/lib/games/star_duel/protocol.js";
import { playMatch } from "../../../support/games/harness.js";

describe("the debris field over P2P", () => {
  let match;

  afterEach(() => {
    match?.stop();
    match?.restore();
  });

  it("is the host's on the guest's screen, though each side drew its own seed", async () => {
    // No shared match seed: each engine draws its own, as two browsers do.
    match = await playMatch({ gameId: "debris_field", mode: "p2p", seed: 2 });
    match.runUntil(() => match.engines.host.gameState.phase === PHASE.PLAYING, 30_000);
    match.advance(100);

    const where = (side) => match.engines[side].gameState.asteroids.map(({ x, y }) => [x, y]);
    expect(where("guest")).toEqual(where("host"));
  });
});
