import { describe, it, expect } from "vitest";
import { FakePointerGame } from "./fake_game.js";
import { matchPerTest, recordedMatch } from "./harness.js";

const READY = "84";
const INPUT_STATE = "8e";

describe("playMatch", () => {
  const play = matchPerTest();

  /** The timers left once a match played for six seconds is stopped. */
  const leftAfterStop = async (options) => {
    const match = await play({ gameId: "hex_pong", mode: "p2p", ...options });
    match.advance(6000);
    match.stop();
    return match.pendingTimers();
  };

  it("plays both sides of a P2P match over the channel", async () => {
    const match = await play({ gameId: "hex_pong", mode: "p2p" });
    match.advance(5000);
    const record = match.record();

    expect(record.wire.some((d) => d.dir === "guest>host" && d.hex.startsWith(READY))).toBe(true);
    expect(record.phases.filter((p) => p.side === "host").map((p) => p.phase)).toContain(1);
    expect(record.phases.some((p) => p.side === "guest" && p.phase === 1)).toBe(true);
  });

  it("delivers each side's keys to that side only", async () => {
    const match = await play({
      gameId: "hex_pong",
      mode: "p2p",
      script: [{ at: 4500, side: "guest", key: "ArrowUp", down: true }],
    });
    match.advance(5000);
    const inputs = match.record().wire.filter((d) => d.hex.startsWith(INPUT_STATE));

    expect(inputs.length).toBeGreaterThan(0);
    expect(inputs.every((d) => d.dir === "guest>host")).toBe(true);
    // [type][seq u16][mask u16]: Pong's `up` is bit 0.
    expect(inputs.some((d) => d.hex.slice(6, 8) === "01")).toBe(true);
  });

  it("plays a solo match against the AI to its end", async () => {
    const match = await play({ gameId: "hex_pong", mode: "solo" });
    match.runUntil(() => match.results.host.length > 0, 600_000);

    expect(match.results.host).toHaveLength(1);
    expect(match.results.host[0]).toHaveProperty("winner");
  });

  it("records a frame drawn in each phase", async () => {
    const match = await play({ gameId: "hex_pong", mode: "solo" });
    match.advance(5000);
    const draws = match.record().draws.filter((d) => d.side === "host");

    expect(draws.length).toBeGreaterThan(1);
    expect(draws.every((d) => d.ops > 0 && /^[0-9a-f]{16}$/.test(d.digest))).toBe(true);
  });

  it("records the sounds a side plays", async () => {
    const match = await play({ gameId: "hex_pong", mode: "solo" });
    match.advance(5000);

    expect(match.record().sounds.host.some(([, op]) => op === "createOscillator")).toBe(true);
  });

  it("records the same match the same way twice", async () => {
    const record = () => recordedMatch({ gameId: "hex_pong", mode: "solo", seed: 9 }, 20_000);

    expect(await record()).toEqual(await record());
  });

  // The check above means nothing unless the recording sees the dice: two
  // seeds must give two different matches.
  it("records a different match for a different seed", async () => {
    const record = (seed) => recordedMatch({ gameId: "hex_pong", mode: "solo", seed }, 20_000);

    expect(await record(9)).not.toEqual(await record(10));
  });

  it("leaves no timer behind once stopped", async () => {
    expect(await leftAfterStop()).toBe(0);
  });

  it("counts only the engines' timers as left behind, not the script's", async () => {
    expect(
      await leftAfterStop({ script: [{ at: 60_000, side: "host", key: "ArrowUp", down: true }] }),
    ).toBe(0);
  });

  it("closing the channel ends a P2P match as disconnected", async () => {
    const match = await play({ gameId: "hex_pong", mode: "p2p" });
    match.advance(8000);
    match.close();
    match.advance(100);

    expect(match.results.host.at(-1)).toMatchObject({ disconnected: true });
  });

  it("plays a pointer script on the canvas, the way a finger would", async () => {
    const match = await play({
      EngineClass: FakePointerGame,
      gameId: "fake_pointer",
      mode: "solo",
      script: [
        { at: 100, side: "host", pointer: "down", x: 50, y: 60 },
        { at: 200, side: "host", pointer: "up", x: 52, y: 61 },
      ],
    });
    match.advance(300);

    expect(match.engines.host.gameState.log.map((entry) => entry.slice(1))).toEqual([
      ["down", 50, 60],
      ["up", 52, 61],
    ]);
  });
});
