import { afterEach, describe, expect, it, vi } from "vitest";
import { AUTOPILOT_GLOBAL, AUTOPILOT_META } from "../../../../js/lib/games/core/autopilot.js";
import { PHASE } from "../../../../js/lib/games/surround/protocol.js";
import { matchPerTest } from "../../../support/games/harness.js";

// The round's banner says who crashed: the guest, and anyone watching, read
// it from the snapshot, which carries the scores but not the crash.
describe("a round over, on the guest's screen", () => {
  const play = matchPerTest({ gameId: "light_trails" });

  afterEach(() => document.head.querySelector(AUTOPILOT_META)?.remove());

  it("names the cycle that crashed, as the host's does", async () => {
    const meta = document.createElement("meta");
    meta.name = "rhc-autopilot";
    meta.content = "allowed";
    document.head.appendChild(meta);
    vi.stubGlobal(AUTOPILOT_GLOBAL, { difficulty: "hard" });
    const match = await play({ mode: "p2p", seed: 2 });
    const { host, guest } = match.engines;

    const seen = new Set();
    for (let t = 0; t < 240 && seen.size < 2; t++) {
      match.advance(250);
      const s = host.gameState;
      if (s.phase !== PHASE.ROUND_OVER || guest.gameState.phase !== PHASE.ROUND_OVER) continue;
      const crashed = s.p1Dead ? 1 : 2;
      seen.add(crashed);
      expect(guest.gameState.p1Dead).toBe(s.p1Dead);
      expect(guest.gameState.p2Dead).toBe(s.p2Dead);
    }
    // Seed 2 has rounds won by either cycle: both banners were checked.
    expect(seen).toEqual(new Set([1, 2]));
  }, 30_000);
});
