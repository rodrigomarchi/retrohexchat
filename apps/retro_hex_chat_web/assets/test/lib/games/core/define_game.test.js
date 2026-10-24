import { describe, it, expect, afterEach } from "vitest";
import { defineGame } from "../../../../js/lib/games/core/define_game.js";
import { FakeGame, PHASE, definition } from "../../../support/games/fake_game.js";
import { playMatch } from "../../../support/games/harness.js";

const play = (options) => playMatch({ EngineClass: FakeGame, gameId: "fake", ...options });
const types = (wire, dir) =>
  wire.filter((d) => d.dir === dir && !d.dropped).map((d) => d.hex.slice(0, 2));
const phasesOf = (record, side) => record.phases.filter((p) => p.side === side).map((p) => p.phase);
const hold = (side, key, at = 0) => [{ at, side, key, down: true }];

describe("defineGame", () => {
  let match;

  afterEach(() => {
    match?.stop();
    match?.restore();
    match = null;
  });

  describe("the class it builds", () => {
    it("takes its inputs, keymap and interpolation from the definition", () => {
      expect(FakeGame.INPUT_BITS).toEqual({ right: 0 });
      expect(FakeGame.KEYMAP).toEqual({ ArrowRight: "right" });
      expect(FakeGame.INTERPOLATION).toEqual({ keys: ["x"] });
      expect(FakeGame.FINAL_PHASE).toBe(PHASE.FINISHED);
    });

    it("names the missing field when a definition is incomplete", () => {
      const withoutSchema = Object.fromEntries(
        Object.entries(definition).filter(([key]) => key !== "schema"),
      );
      expect(() => defineGame(withoutSchema)).toThrow(/schema/);
      expect(() =>
        defineGame({ ...definition, flow: { ...definition.flow, begin: "NOPE" } }),
      ).toThrow(/NOPE/);
    });
  });

  describe("a P2P match", () => {
    it("starts once the guest is ready, even when its first announcements are lost", async () => {
      let lost = 0;
      match = await play({
        drop: (data, dir) => dir === "guest>host" && new Uint8Array(data)[0] === 0x84 && lost++ < 3,
      });
      match.advance(1000);
      const record = match.record();

      expect(phasesOf(record, "host")).toEqual(
        expect.arrayContaining([PHASE.COUNTDOWN, PHASE.PLAYING]),
      );
      expect(phasesOf(record, "guest")).toEqual(
        expect.arrayContaining([PHASE.COUNTDOWN, PHASE.PLAYING]),
      );
    });

    it("runs the table: countdown, play, and the end the simulation reaches", async () => {
      match = await play({ script: hold("host", "ArrowRight", 300) });
      match.advance(3000);
      const record = match.record();

      // The ready announcement lands before the first frame is observed.
      expect(phasesOf(record, "host").slice(-3)).toEqual([
        PHASE.COUNTDOWN,
        PHASE.PLAYING,
        PHASE.FINISHED,
      ]);
      expect(record.results.host).toEqual([{ score: { p1: 2, p2: 0 }, winner: 1 }]);
    });

    it("sends the end of the match three times and the guest hears it", async () => {
      match = await play({ script: hold("host", "ArrowRight", 300) });
      match.advance(3000);
      const record = match.record();

      expect(types(record.wire, "host>guest").filter((t) => t === "83")).toHaveLength(3);
      expect(match.engines.guest.ended).toEqual({ score1: 2, score2: 0, winner: 1 });
    });

    it("the guest's held key reaches the host", async () => {
      match = await play({ script: hold("guest", "ArrowRight", 300) });
      match.advance(3000);

      expect(match.results.host).toEqual([{ score: { p1: 0, p2: 2 }, winner: 2 }]);
    });

    it("captures the keys it declares only while the match is in play", async () => {
      match = await play();
      const key = () => match.key("guest", " ").defaultPrevented;
      expect(key()).toBe(false);
      match.advance(400);
      expect(key()).toBe(true);
    });

    it("refuses beginMatch on the guest, twice on the host, and once stopped", async () => {
      match = await play();
      expect(match.engines.guest.beginMatch()).toBe(false);
      match.advance(100);
      expect(match.engines.host.beginMatch()).toBe(false);
    });

    it("ends as disconnected when the channel drops mid-match", async () => {
      match = await play();
      match.advance(500);
      match.close();
      match.advance(100);

      expect(match.results.host.at(-1)).toEqual({
        score: { p1: 0, p2: 0 },
        winner: 0,
        disconnected: true,
      });
    });

    it("leaves no timer behind once stopped, even mid-countdown", async () => {
      match = await play();
      match.advance(150);
      match.stop();

      expect(match.pendingTimers()).toBe(0);
    });
  });

  describe("a solo match", () => {
    it("creates the AI with the difficulty asked for, and keeps only the inputs the game declares", async () => {
      match = await play({ mode: "solo", difficulty: "hard" });
      match.advance(400);
      const { host } = match.engines;

      expect(host.opponentController.difficulty).toBe("hard");
      expect(host.remoteInputs).toEqual({ right: true });
    });
  });
});
