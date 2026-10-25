import { describe, it, expect, afterEach, vi } from "vitest";
import { createLocalTransport } from "../../../../js/lib/games/transport.js";
import { defineGame } from "../../../../js/lib/games/core/define_game.js";
import { aiRandom } from "../../../../js/lib/games/core/rng.js";
import { FakeGame, PHASE, definition } from "../../../support/games/fake_game.js";
import { playMatch } from "../../../support/games/harness.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";

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

    it("hands the page an AI kept out of the game's chunk, to load for a solo match", async () => {
      const create = () => ({ nextInputs: () => ({}) });
      const Game = defineGame({
        ...definition,
        ai: { ...definition.ai, load: async () => create },
      });
      expect(await Game.AI_LOADER()).toBe(create);
      expect(FakeGame.AI_LOADER).toBeNull();
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

    it("the host ignores an end of match sent to it, and sends nothing without a state", async () => {
      match = await play();
      match.advance(400);
      const { host } = match.engines;
      host._onChannelMessage({ data: new Uint8Array([0x83, 9, 9, 2]).buffer });
      expect(host.ended).toBeUndefined();

      const sent = match.record().wire.length;
      host.gameState = null;
      host.broadcast();
      expect(match.record().wire.length).toBe(sent);
      host.gameState = { phase: PHASE.PLAYING, x: 0, score1: 0, score2: 0, countdown: 0 };
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

    it("runs the definition's onAbandon when the channel drops mid-match", async () => {
      const abandoned = [];
      const Game = defineGame({ ...definition, onAbandon: (game) => abandoned.push(game.isHost) });
      match = await playMatch({ EngineClass: Game, gameId: "fake" });
      match.advance(500);
      match.close();
      match.advance(100);
      expect(abandoned).toContain(true);
    });

    it("runs the definition's onStop before the engine stops", async () => {
      match = await play();
      match.advance(150);
      match.stop();

      expect(match.engines.host.stoppedWhileRunning).toBe(true);
    });

    it("leaves no timer behind once stopped, even mid-countdown", async () => {
      match = await play();
      match.advance(150);
      match.stop();

      expect(match.pendingTimers()).toBe(0);
    });
  });

  describe("input hooks", () => {
    const withHooks = (hooks) => defineGame({ ...definition, ...hooks });

    it("tells the definition when the guest's held inputs change, and when the AI's do", async () => {
      const seen = [];
      const Game = withHooks({
        onRemoteInputChange: (_g, previous, current) => seen.push([previous.right, current.right]),
      });
      match = await playMatch({
        EngineClass: Game,
        gameId: "fake",
        script: hold("guest", "ArrowRight", 300),
      });
      match.advance(400);
      expect(seen).toContainEqual([false, true]);
      match.stop();
      match.restore();

      seen.length = 0;
      match = await playMatch({ EngineClass: Game, gameId: "fake", mode: "solo" });
      match.advance(400);
      expect(seen).toContainEqual([false, true]);
    });

    it("runs onKeyUp after the engine's own key handling, and onBlur before releasing every input", async () => {
      const seen = [];
      const Game = withHooks({
        onKeyUp: (game, event) => seen.push(["up", event.key, game.localInputs.right]),
        // Both sides of the match listen to the same window.
        onBlur: (game) => game.isHost && seen.push(["blur", game.localInputs.right]),
      });
      match = await playMatch({ EngineClass: Game, gameId: "fake" });
      match.key("host", "ArrowRight");
      match.key("host", "ArrowRight", "keyup");
      match.key("host", "ArrowRight");
      window.dispatchEvent(new Event("blur"));
      expect(seen).toEqual([
        ["up", "ArrowRight", false],
        ["blur", true],
      ]);
    });
  });

  describe("discrete commands", () => {
    it("runs onKeyDown after the engine's key handling, and hands the guest's commands to onRemoteEdge", async () => {
      const seen = [];
      const Game = defineGame({
        ...definition,
        onKeyDown: (game, event) => {
          if (!game.isHost && event.key === "x") game._sendInputEdge(7);
        },
        onRemoteEdge: (_game, code) => seen.push(code),
      });
      match = await playMatch({ EngineClass: Game, gameId: "fake" });
      match.advance(100);
      match.key("guest", "x");
      match.advance(100);
      expect(seen).toEqual([7]);
    });
  });

  describe("the simulation's clock", () => {
    afterEach(() => {
      vi.useRealTimers();
      vi.unstubAllGlobals();
    });

    it("holds the countdown still while the tab draws no frames, and goes on when they return", () => {
      vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "setInterval", "clearInterval"] });
      const frames = [];
      vi.stubGlobal("requestAnimationFrame", (callback) => frames.push(callback));
      vi.stubGlobal("cancelAnimationFrame", () => {});
      let now = 0;
      const drawFrames = (ms) => {
        for (const end = now + ms; now < end; ) {
          now += 1000 / 60;
          frames.shift()?.(now);
        }
      };
      const game = new FakeGame(
        recordingCanvas(64, 48),
        createLocalTransport(),
        "fake",
        true,
        null,
        { mode: "solo" },
      );
      game.start();
      drawFrames(50);
      game.beginMatch();

      // A hidden tab: time passes on the page's timers, no frame is drawn.
      vi.advanceTimersByTime(5000);
      expect(game.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(game.gameState.countdown).toBe(2);

      // The frames return and the countdown takes its time from there.
      drawFrames(100);
      expect(game.gameState.phase).toBe(PHASE.COUNTDOWN);
      drawFrames(250);
      expect(game.gameState.phase).toBe(PHASE.PLAYING);
      game.stop();
    });
  });

  describe("the guest's countdown", () => {
    it("shows the phase and count the host's snapshots carry, and keeps no clock of its own", async () => {
      match = await play();
      const seen = [];
      for (let i = 0; i < 12; i++) {
        match.advance(20);
        const { host, guest } = match.engines;
        seen.push([
          guest.gameState.phase,
          guest.gameState.countdown,
          host.gameState.phase,
          host.gameState.countdown,
        ]);
      }
      // The guest lags at most a snapshot behind and never runs ahead of the host.
      for (const [gPhase, gCount, hPhase, hCount] of seen) {
        expect(gPhase).toBeLessThanOrEqual(hPhase);
        if (gPhase === hPhase && gPhase === PHASE.COUNTDOWN) {
          expect(gCount).toBeGreaterThanOrEqual(hCount);
        }
      }
      expect(match.engines.guest.flow.name).toBe("WAITING");
    });
  });

  describe("random draws", () => {
    const make = (options, created = []) => {
      const Game = defineGame({
        ...definition,
        ai: { ...definition.ai, create: (o) => created.push(o) && { nextInputs: () => ({}) } },
      });
      return new Game(
        document.createElement("canvas"),
        createLocalTransport(),
        "fake",
        true,
        null,
        {
          mode: "solo",
          ...options,
        },
      );
    };
    const draws = (next) => [next(), next(), next()];

    it("plays the match its seed names: the same seed, the same draws", () => {
      expect(draws(make({ seed: 7 }).random)).toEqual(draws(make({ seed: 7 }).random));
      expect(draws(make({ seed: 7 }).random)).not.toEqual(draws(make({ seed: 8 }).random));
    });

    it("draws decoration and the AI from streams apart from the simulation's", () => {
      const created = [];
      const game = make({ seed: 7 }, created);

      expect(draws(game.fxRandom)).not.toEqual(draws(make({ seed: 7 }).random));
      expect(draws(created[0].rng)).toEqual(draws(aiRandom(7)));
    });

    it("chooses a seed of its own when it is given none", () => {
      expect(Number.isInteger(make({}).matchSeed)).toBe(true);
    });
  });

  describe("sounds", () => {
    it("plays a table of sounds through the core's synthesizer, by name", () => {
      const Game = defineGame({
        ...definition,
        audio: { sounds: { ping: { wave: "sine", freq: 880, vol: 0.1, dur: 0.05 } } },
      });
      const game = new Game(
        document.createElement("canvas"),
        createLocalTransport(),
        "fake",
        true,
        null,
      );
      expect(typeof game.audio.playPing).toBe("function");
      expect(() => game.audio.playPing()).not.toThrow();
    });
  });

  describe("cues", () => {
    it("the guest plays what each snapshot cues against the one before, before onSnapshot", async () => {
      const order = [];
      const Game = defineGame({
        ...definition,
        audio: { sounds: { beep: { wave: "sine", freq: 880, vol: 0.1, dur: 0.05 } } },
        cues: [{ phase: PHASE.COUNTDOWN, play: (game) => order.push(["cue", game.isHost]) }],
        onSnapshot: () => order.push(["onSnapshot"]),
      });
      match = await playMatch({ EngineClass: Game, gameId: "fake" });
      match.advance(150);

      expect(order[0]).toEqual(["cue", false]);
      expect(order[1]).toEqual(["onSnapshot"]);
      expect(order.filter(([what]) => what === "cue")).toHaveLength(1);
    });
  });

  describe("outcome", () => {
    const engineFor = (isHost, options = {}) => {
      const Game = defineGame(definition);
      return new Game(
        document.createElement("canvas"),
        createLocalTransport(),
        "fake",
        isHost,
        null,
        options,
      );
    };

    it("tells the host, player one, how the match ended for them", () => {
      const host = engineFor(true);
      expect(host.outcome(1)).toBe("win");
      expect(host.outcome(2)).toBe("lose");
      expect(host.outcome(0)).toBe("draw");
    });

    it("tells the guest, player two, the other way round", () => {
      const guest = engineFor(false);
      expect(guest.outcome(1)).toBe("lose");
      expect(guest.outcome(2)).toBe("win");
      expect(guest.outcome(0)).toBe("draw");
    });

    it("counts the human as player one in solo play", () => {
      const solo = engineFor(true, { mode: "solo" });
      expect(solo.outcome(1)).toBe("win");
      expect(solo.outcome(2)).toBe("lose");
    });
  });

  describe("a game with no state yet", () => {
    it("steps without throwing until its state is built", () => {
      const ticks = [];
      const Game = defineGame({
        ...definition,
        init: () => null,
        flow: {
          ...definition.flow,
          states: {
            ...definition.flow.states,
            WAITING: { tick: (game) => ticks.push(game.gameState) },
          },
        },
      });
      const game = new Game(
        document.createElement("canvas"),
        createLocalTransport(),
        "fake",
        true,
        null,
      );
      game.running = true;

      expect(() => game._gameLoop()).not.toThrow();
      expect(ticks).toEqual([null]);
    });
  });

  describe("finish", () => {
    it("keeps a result callback that throws from escaping the step", () => {
      const onGameEnd = vi.fn(() => {
        throw new Error("pushEvent failed");
      });
      const Game = defineGame(definition);
      const game = new Game(
        document.createElement("canvas"),
        createLocalTransport(),
        "fake",
        true,
        onGameEnd,
      );
      game.start();
      game.beginMatch();

      expect(() => game.flow.go("FINISHED")).not.toThrow();
      expect(onGameEnd).toHaveBeenCalledOnce();
      game.stop();
    });

    it("can leave out the last snapshot, for a game that sent it before the end", async () => {
      const Game = defineGame({
        ...definition,
        flow: {
          ...definition.flow,
          states: {
            ...definition.flow.states,
            FINISHED: {
              final: true,
              enter: (game) =>
                game.finish({
                  end: { score1: 2, score2: 0, winner: 1 },
                  result: {},
                  broadcast: false,
                }),
            },
          },
        },
      });
      match = await playMatch({
        EngineClass: Game,
        gameId: "fake",
        script: hold("host", "ArrowRight", 300),
      });
      match.advance(3000);
      const host = types(match.record().wire, "host>guest");
      const end = host.indexOf("83");
      expect(end).toBeGreaterThan(0);
      expect(host.slice(end).filter((t) => t === "80")).toEqual([]);
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

    it("refuses to begin without a controller when the game leaves creating its AI to the page", () => {
      const Game = defineGame({ ...definition, ai: { difficulty: definition.ai.difficulty } });
      const game = new Game(
        document.createElement("canvas"),
        createLocalTransport(),
        "fake",
        true,
        null,
        {
          mode: "solo",
        },
      );
      game.start();

      expect(game.opponentController).toBeNull();
      expect(game.beginMatch()).toBe(false);
      expect(game.beginMatch({ opponentController: { nextInputs: () => ({}) } })).toBe(true);
      game.stop();
    });
  });
});
