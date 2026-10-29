import { describe, expect, it, vi } from "vitest";
import {
  ARROW_KEYS,
  ARROWS_WASD_SPACE,
  drawSeed,
  freshOnHost,
  packedSnapshot,
  seededInit,
} from "../../../../js/lib/games/core/define_game.js";
import { raceEnd } from "../../../../js/lib/games/core/result.js";
import { FakeGame } from "../../../support/games/fake_game.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";
import { createLocalTransport } from "../../../../js/lib/games/transport.js";

const MODES = { racer: 3 };
const create = (mode, seed) => ({ mode, seed });

describe("the keys of each direction", () => {
  it("are its arrow and its WASD letter in either case, all of them captured keys", () => {
    expect(ARROW_KEYS.left).toEqual(["ArrowLeft", "a", "A"]);
    for (const keys of Object.values(ARROW_KEYS)) {
      for (const key of keys) expect(ARROWS_WASD_SPACE).toContain(key);
    }
  });
});

describe("a seeded game", () => {
  it("drawSeed turns the match's draw into a 32-bit seed", () => {
    expect(drawSeed({ random: () => 0.5 })).toBe(0x7fffffff);
  });

  it("seededInit picks the mode by game id and lets only the host draw the seed", () => {
    const init = seededInit(MODES, 0, create);
    const host = { gameId: "racer", isHost: true, random: () => 0.5 };
    const guest = { gameId: "other", isHost: false, random: vi.fn() };

    expect(init(host)).toEqual({ mode: 3, seed: 0x7fffffff });
    expect(init(guest)).toEqual({ mode: 0, seed: 0 });
    expect(guest.random).not.toHaveBeenCalled();
  });

  it("freshOnHost starts the host again from its mode and seed, and leaves the guest", () => {
    const onStart = freshOnHost(create);
    const host = { isHost: true, gameMode: 1, seed: 9, gameState: null };
    const guest = { isHost: false, gameMode: 1, seed: 9, gameState: "theirs" };
    onStart(host);
    onStart(guest);
    expect(host.gameState).toEqual({ mode: 1, seed: 9 });
    expect(guest.gameState).toBe("theirs");
  });

  it("packedSnapshot sends the state packed and takes the mode with the state it unpacks", () => {
    const { toWire, applySnapshot } = packedSnapshot(
      (state) => ({ flat: state.nested.value, mode: state.mode }),
      (decoded) => ({ nested: { value: decoded.flat } }),
    );
    const guest = {};
    expect(toWire({ gameState: { nested: { value: 7 }, mode: 2 } })).toEqual({ flat: 7, mode: 2 });
    applySnapshot(guest, { flat: 7, mode: 2 });
    expect(guest).toEqual({ gameMode: 2, gameState: { nested: { value: 7 } } });
  });
});

describe("forgetMatch", () => {
  it("lets go of every input, forgets the peer and counts frames from 0", () => {
    const game = new FakeGame(recordingCanvas(64, 48), createLocalTransport(), "fake", true, null, {
      mode: "solo",
    });
    game.localInputs = { right: true };
    game.remoteInputs = { right: true };
    game.peerReady = true;
    game.frameCount = 40;

    game.forgetMatch();

    expect(game.localInputs).toEqual({ right: false });
    expect(game.remoteInputs).toEqual({ right: false });
    expect([game.peerReady, game.frameCount]).toEqual([false, 0]);
  });
});

describe("raceEnd", () => {
  it("shows the guest's race finished, quiets it, then plays who won", () => {
    const log = [];
    const game = {
      gameState: { phase: 2 },
      invalidate: () => log.push("invalidate"),
      setKeyboardCaptured: (on) => log.push(`capture ${on}`),
      outcome: (winner) => (winner === 2 ? "win" : "lose"),
      audio: { playVictory: () => log.push("victory"), playGameOver: () => log.push("over") },
    };
    raceEnd(5, () => log.push("quiet"))(game, { winner: 2 });

    expect(game.gameState).toEqual({ phase: 5 });
    expect(log).toEqual(["invalidate", "capture false", "quiet", "victory"]);
  });

  it("leaves a guest that never had a state without one", () => {
    const game = {
      gameState: null,
      invalidate: () => {},
      setKeyboardCaptured: () => {},
      outcome: () => "lose",
      audio: { playVictory: () => {}, playGameOver: () => {} },
    };
    raceEnd(5, () => {})(game, { winner: 1 });
    expect(game.gameState).toBeNull();
  });
});
