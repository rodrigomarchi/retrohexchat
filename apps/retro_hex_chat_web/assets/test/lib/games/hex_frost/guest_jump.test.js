import { describe, expect, it } from "vitest";
import { BAILEY_STATE, PHASE } from "../../../../js/lib/games/hex_frost/protocol.js";
import { matchPerTest } from "../../../support/games/harness.js";

// The guest's keys reach the host as a held mask, restated every step. The
// host cleared a jump after each step, so a guest still holding the key when
// a jump ended jumped again — into the water — where the host, whose key
// press comes once, did not. A jump is a press, on both seats.
describe("a guest's jump", () => {
  const play = matchPerTest({ gameId: "hex_frost_peaceful" });

  it("is one jump per press, held or not, as the host's is", async () => {
    const match = await play({ mode: "p2p", seed: 3 });
    match.advance(4_500);
    expect(match.engines.host.gameState.phase).toBe(PHASE.BUILDING);

    const jumps = () => {
      let count = 0;
      let jumping = false;
      return (state) => {
        const now = state.p2.state === BAILEY_STATE.JUMPING;
        if (now && !jumping) count++;
        jumping = now;
        return count;
      };
    };
    const seen = jumps();
    const watch = (ms) => {
      let count = 0;
      for (let t = 0; t < ms; t += 1000 / 60) {
        match.advance(1000 / 60);
        count = seen(match.engines.host.gameState);
      }
      return count;
    };

    match.key("guest", "ArrowDown");
    expect(watch(1_500)).toBe(1);
    match.key("guest", "ArrowDown", "keyup");
    watch(200);
    match.key("guest", "ArrowUp");
    expect(watch(800)).toBe(2);
    match.key("guest", "ArrowUp", "keyup");
  });
});
