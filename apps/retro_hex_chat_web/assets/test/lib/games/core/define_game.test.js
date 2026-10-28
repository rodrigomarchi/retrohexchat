import { describe, it, expect, afterEach, vi } from "vitest";
import { createLocalTransport } from "../../../../js/lib/games/transport.js";
import { defineGame } from "../../../../js/lib/games/core/define_game.js";
import { aiRandom } from "../../../../js/lib/games/core/rng.js";
import {
  FakeGame,
  FakePointerGame,
  FakeTwoButtonGame,
  FakeSoloGame,
  pointerDefinition,
  PHASE,
  SNAPSHOT,
  definition,
  soloDefinition,
} from "../../../support/games/fake_game.js";
import { playMatch } from "../../../support/games/harness.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";

const play = (options) => playMatch({ EngineClass: FakeGame, gameId: "fake", ...options });
const types = (wire, dir) =>
  wire.filter((d) => d.dir === dir && !d.dropped).map((d) => d.hex.slice(0, 2));
const phasesOf = (record, side) => record.phases.filter((p) => p.side === side).map((p) => p.phase);
const hold = (side, key, at = 0) => [{ at, side, key, down: true }];

/** A transport's close event, which a test can fire. */
function closable() {
  const target = new EventTarget();
  return {
    addEventListener: (type, listener) => target.addEventListener(type, listener),
    removeEventListener: (type, listener) => target.removeEventListener(type, listener),
    close: () => target.dispatchEvent(new Event("close")),
  };
}

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

  describe("a one-player game", () => {
    const solo = (options) =>
      playMatch({ EngineClass: FakeSoloGame, gameId: "fake_solo", mode: "solo", ...options });
    const without = (key) =>
      Object.fromEntries(Object.entries(soloDefinition).filter(([field]) => field !== key));
    const engine = (mode, transport = createLocalTransport()) =>
      new FakeSoloGame(recordingCanvas(64, 48), transport, "fake_solo", true, null, { mode });

    it("needs no wire, no opponent and no disconnect result, but the score as it stands", () => {
      expect(() => defineGame(soloDefinition)).not.toThrow();
      expect(() => defineGame(without("standing"))).toThrow(/standing/);
      expect(() => defineGame(without("players"))).toThrow(/schema/);
    });

    it("refuses an opponent", () => {
      expect(() => defineGame({ ...soloDefinition, ai: definition.ai })).toThrow(/no opponent/);
    });

    it("plays solo only", () => {
      expect(() => engine("p2p_host")).toThrow(/one-player/);
      expect(() => engine("p2p_guest")).toThrow(/one-player/);
      expect(() => engine("spectator")).toThrow(/one-player/);
      expect(() => engine("solo").stop()).not.toThrow();
    });

    it("begins without an opponent and reports its end once", async () => {
      match = await solo({ script: hold("host", "ArrowRight") });
      expect(match.engines.host.opponentController ?? null).toBeNull();
      match.advance(1000);

      expect(phasesOf(match.record(), "host").slice(-2)).toEqual([PHASE.PLAYING, PHASE.FINISHED]);
      expect(match.results.host).toEqual([{ score: { p1: 3, p2: 0 }, winner: 0 }]);
    });

    it("writes nothing to the transport, through the match and its end", async () => {
      match = await solo({ script: hold("host", "ArrowRight") });
      const send = vi.spyOn(match.engines.host.transport, "send");
      match.advance(1000);

      expect(match.results.host).toHaveLength(1);
      expect(send).not.toHaveBeenCalled();
      // A two-player end repeats itself on timers; this one leaves none.
      match.stop();
      expect(match.pendingTimers()).toBe(0);
    });

    it("reports nothing when its transport closes", () => {
      const transport = { ...createLocalTransport(), ...closable() };
      const results = [];
      const game = new FakeSoloGame(
        recordingCanvas(64, 48),
        transport,
        "fake_solo",
        true,
        (result) => results.push(result),
        { mode: "solo" },
      );
      game.start();
      game.beginMatch();
      transport.close();
      game.stop();

      expect(results).toEqual([]);
    });
  });

  describe("a pointer game", () => {
    const pointerMatch = (options) =>
      playMatch({ EngineClass: FakePointerGame, gameId: "fake_pointer", mode: "solo", ...options });
    const logOf = (m) => m.engines.host.gameState.log;

    it("hands a press over on the next tick, in canvas pixels, and not before", async () => {
      match = await pointerMatch({});
      match.advance(100);
      match.pointer("down", 100, 50);

      expect(logOf(match)).toEqual([]);
      match.advance(17);
      expect(logOf(match)).toHaveLength(1);
      expect(logOf(match)[0].slice(1)).toEqual(["down", 100, 50]);
    });

    it("lets go of a press held when the match is paused, on resume, and takes none meanwhile", async () => {
      match = await pointerMatch({});
      match.advance(100);
      match.pointer("down", 100, 50);
      match.advance(17);
      const { host } = match.engines;

      expect(host.pause()).toBe(true);
      match.pointer("up", 100, 50);
      match.advance(200);
      expect(logOf(match).map((entry) => entry[1])).toEqual(["down"]);

      host.resume();
      match.advance(100);
      expect(logOf(match).map((entry) => entry[1])).toEqual(["down", "cancel"]);
    });

    it("reads the press where the picture is drawn, not where the element is", async () => {
      // A 640×480 picture in a 1280×960 element: every pixel is two.
      match = await pointerMatch({ rect: { left: 0, top: 0, width: 1280, height: 960 } });
      match.advance(100);
      match.pointer("down", 640, 480);
      match.advance(17);

      expect(logOf(match)[0].slice(1)).toEqual(["down", 320, 240]);
    });

    it("hands over the events of one frame in the order they happened", async () => {
      match = await pointerMatch({});
      match.advance(100);
      match.pointer("down", 10, 10);
      match.pointer("move", 20, 10);
      match.pointer("up", 30, 10);
      match.advance(17);

      expect(logOf(match).map((entry) => entry.slice(1))).toEqual([
        ["down", 10, 10],
        ["move", 20, 10],
        ["up", 30, 10],
      ]);
      // All three in the same tick.
      expect(new Set(logOf(match).map(([tick]) => tick)).size).toBe(1);
    });

    it("follows only the first finger, and ignores a press off the picture", async () => {
      match = await pointerMatch({ rect: { left: 0, top: 0, width: 1000, height: 480 } });
      match.advance(100);
      match.pointer("down", 100, 100);
      match.pointer("down", 500, 100, { pointerId: 1 });
      match.pointer("down", 500, 100, { pointerId: 2 });
      match.pointer("move", 600, 100, { pointerId: 2 });
      match.advance(17);

      expect(logOf(match).map((entry) => entry.slice(1))).toEqual([["down", 320, 100]]);
    });

    it("takes a press of the main button only: a right or middle click plays nothing", async () => {
      match = await pointerMatch({});
      match.advance(100);
      match.pointer("down", 10, 10, { button: 2 });
      match.pointer("up", 10, 10, { button: 2 });
      match.pointer("down", 10, 10, { button: 1 });
      match.advance(17);

      expect(logOf(match)).toEqual([]);
    });

    it("takes the secondary button when the game asks for it, and keeps the menu away", async () => {
      match = await playMatch({
        EngineClass: FakeTwoButtonGame,
        gameId: "fake_pointer",
        mode: "solo",
      });
      match.advance(100);
      match.pointer("down", 10, 10, { button: 2 });
      match.pointer("up", 10, 10, { button: 2 });
      match.pointer("down", 20, 20);
      match.pointer("up", 20, 20);
      match.pointer("down", 10, 10, { button: 1 });
      match.advance(17);

      expect(logOf(match).map((entry) => entry.slice(1))).toEqual([
        ["down", 10, 10, "secondary"],
        ["up", 10, 10, "secondary"],
        ["down", 20, 20, "main"],
        ["up", 20, 20, "main"],
      ]);
      const menu = new MouseEvent("contextmenu", { cancelable: true });
      match.engines.host.canvas.dispatchEvent(menu);
      expect(menu.defaultPrevented).toBe(true);
    });

    it("leaves the browser's menu to a game that takes the main button only", async () => {
      match = await pointerMatch({});
      const menu = new MouseEvent("contextmenu", { cancelable: true });
      match.engines.host.canvas.dispatchEvent(menu);
      expect(menu.defaultPrevented).toBe(false);
    });

    it("cancels a press when the window loses focus", async () => {
      match = await pointerMatch({});
      match.advance(100);
      match.pointer("down", 10, 10);
      window.dispatchEvent(new Event("blur"));
      match.advance(17);

      expect(logOf(match).map((entry) => entry[1])).toEqual(["down", "cancel"]);
    });

    it("hands over presses while it waits to begin", async () => {
      match = await pointerMatch({ begin: false });
      match.advance(100);
      match.pointer("down", 10, 10);
      match.advance(17);

      expect(logOf(match).map((entry) => entry[1])).toEqual(["down"]);
    });

    it("ends where a press ends it", async () => {
      match = await pointerMatch({});
      match.advance(100);
      match.pointer("down", 1, 1);
      match.advance(100);

      expect(match.results.host).toEqual([{ score: { p1: 1, p2: 0 }, winner: 0 }]);
    });

    it("leaves the canvas alone in a game played without a pointer", () => {
      const canvas = recordingCanvas(64, 48);
      const listen = vi.spyOn(canvas, "addEventListener");
      const game = new FakeSoloGame(canvas, createLocalTransport(), "fake_solo", true, null, {
        mode: "solo",
      });
      game.start();
      game.stop();

      expect(
        listen.mock.calls.map(([type]) => type).filter((t) => t.startsWith("pointer")),
      ).toEqual([]);
    });

    it("stops listening when it stops", () => {
      const canvas = recordingCanvas(64, 48);
      const listen = vi.spyOn(canvas, "addEventListener");
      const unlisten = vi.spyOn(canvas, "removeEventListener");
      const game = new FakePointerGame(canvas, createLocalTransport(), "fake_pointer", true, null, {
        mode: "solo",
      });
      game.start();
      game.stop();
      const pointerTypes = (spy) =>
        spy.mock.calls.map(([type]) => type).filter((t) => t.startsWith("pointer"));

      expect(pointerTypes(listen).length).toBeGreaterThan(0);
      expect(pointerTypes(unlisten).sort()).toEqual(pointerTypes(listen).sort());
    });
  });

  describe("pixel art and resolution", () => {
    const CrispGame = defineGame({ ...pointerDefinition, pixelArt: true, resolution: 2 });
    const crisp = (canvas = recordingCanvas(640, 480)) =>
      new CrispGame(canvas, createLocalTransport(), "fake_crisp", true, null, { mode: "solo" });

    it("draws a 640×480 game on a canvas of twice the pixels", () => {
      const canvas = recordingCanvas(640, 480);
      const game = crisp(canvas);

      expect([canvas.width, canvas.height]).toEqual([1280, 960]);
      expect(game.view).toEqual({ width: 640, height: 480 });
    });

    it("scales every frame to the game's pixels and draws pixel art unsmoothed", async () => {
      match = await playMatch({ EngineClass: CrispGame, gameId: "fake_crisp", mode: "solo" });
      match.advance(200);
      const { canvas } = match.engines.host;
      canvas.recording = true;
      canvas.clearLog();
      match.engines.host.invalidate();
      match.advance(17);
      const log = canvas.log;
      const draw = log.findIndex(([op]) => op === "fillRect");

      expect(log.slice(0, draw)).toContainEqual(["setTransform", 2, 0, 0, 2, 0, 0]);
      expect(log.slice(0, draw)).toContainEqual(["imageSmoothingEnabled", "=", false]);
      expect(canvas.classList.contains("game-canvas--pixel-art")).toBe(true);
    });

    it("reads a press in the game's pixels on the bigger canvas", async () => {
      match = await playMatch({
        EngineClass: CrispGame,
        gameId: "fake_crisp",
        mode: "solo",
        rect: { left: 0, top: 0, width: 1280, height: 960 },
      });
      match.advance(100);
      match.pointer("down", 640, 480);
      match.advance(17);

      expect(match.engines.host.gameState.log[0].slice(1)).toEqual(["down", 320, 240]);
    });

    it("keeps the touch on the canvas for a pointer game, so a drag does not scroll the page", () => {
      const canvas = recordingCanvas(640, 480);
      new FakePointerGame(canvas, createLocalTransport(), "fake_pointer", true, null, {
        mode: "solo",
      });
      expect(canvas.classList.contains("game-canvas--pointer")).toBe(true);
    });

    it("lets a game choose the picture it draws from the box the page gave its canvas", async () => {
      const Standing = defineGame({
        ...pointerDefinition,
        resolution: 2,
        view: (canvas) => {
          const box = canvas.getBoundingClientRect();
          return box.height > box.width ? { width: 464, height: 720 } : null;
        },
      });
      match = await playMatch({
        EngineClass: Standing,
        gameId: "fake_standing",
        mode: "solo",
        rect: { left: 0, top: 0, width: 360, height: 560 },
      });
      const { host } = match.engines;
      expect(host.view).toEqual({ width: 464, height: 720 });
      expect([host.canvas.width, host.canvas.height]).toEqual([928, 1440]);

      // The picture fills the box's width: a press at its far right is its far right.
      match.advance(100);
      match.pointer("down", 359, 10);
      match.advance(17);
      expect(host.gameState.log[0][2]).toBe(462);
    });

    it("keeps the page's size when the game chooses none", () => {
      const Lying = defineGame({ ...pointerDefinition, resolution: 2, view: () => null });
      const canvas = recordingCanvas(640, 480);
      const game = new Lying(canvas, createLocalTransport(), "fake_lying", true, null, {
        mode: "solo",
      });
      expect(game.view).toEqual({ width: 640, height: 480 });
    });

    it("keeps the size the page gave a canvas a second engine is built on", () => {
      const canvas = recordingCanvas(640, 480);
      crisp(canvas);
      const second = crisp(canvas);

      expect([canvas.width, canvas.height]).toEqual([1280, 960]);
      expect(second.view).toEqual({ width: 640, height: 480 });
    });

    it("changes nothing for a game that asks for neither", async () => {
      const canvas = recordingCanvas(640, 480);
      const game = new FakeSoloGame(canvas, createLocalTransport(), "fake_solo", true, null, {
        mode: "solo",
      });
      expect([canvas.width, canvas.height]).toEqual([640, 480]);
      expect(game.view).toEqual({ width: 640, height: 480 });
      expect([...canvas.classList]).toEqual([]);

      match = await playMatch({ EngineClass: FakeSoloGame, gameId: "fake_solo", mode: "solo" });
      match.advance(200);
      const host = match.engines.host.canvas;
      host.recording = true;
      host.clearLog();
      match.engines.host.invalidate();
      match.advance(17);
      const ops = host.log.map(([op]) => op);
      expect(ops).not.toContain("setTransform");
      expect(ops).not.toContain("imageSmoothingEnabled");
    });

    it("paints no frame while nothing asks for one", async () => {
      match = await playMatch({
        EngineClass: FakePointerGame,
        gameId: "fake_pointer",
        mode: "solo",
      });
      match.advance(200);
      const { canvas } = match.engines.host;
      canvas.recording = true;
      canvas.clearLog();
      match.advance(1000);

      expect(canvas.log.filter(([op]) => op === "fillRect")).toHaveLength(0);
      match.engines.host.invalidate();
      match.advance(17);
      expect(canvas.log.filter(([op]) => op === "fillRect")).toHaveLength(1);
    });
  });

  describe("ending a solo match early", () => {
    it("reports the score as it stands, once, with nobody named the winner", async () => {
      match = await playMatch({
        EngineClass: FakeGame,
        gameId: "fake",
        mode: "solo",
        script: hold("host", "ArrowRight"),
      });
      match.advance(200);
      const { host } = match.engines;
      const standing = { p1: host.gameState.score1, p2: host.gameState.score2 };

      expect(host.quit()).toBe(true);
      expect(host.quit()).toBe(false);
      match.advance(500);

      expect(match.results.host).toEqual([{ score: standing, ended_early: true }]);
      expect(host.gameState.phase).toBe(PHASE.FINISHED);
      expect(host.stepping).toBe(false);
    });

    it("reads a one-player game's standing", async () => {
      match = await playMatch({
        EngineClass: FakeSoloGame,
        gameId: "fake_solo",
        mode: "solo",
        script: hold("host", "ArrowRight"),
      });
      match.advance(300);
      const points = match.engines.host.gameState.points;
      match.engines.host.quit();

      expect(points).toBeGreaterThan(0);
      expect(match.results.host).toEqual([{ score: { p1: points, p2: 0 }, ended_early: true }]);
    });

    it("ends nothing before the match begins, after it ends, or on either side of a P2P match", async () => {
      const waiting = new FakeGame(
        recordingCanvas(64, 48),
        createLocalTransport(),
        "fake",
        true,
        null,
        {
          mode: "solo",
        },
      );
      waiting.start();
      expect(waiting.quit()).toBe(false);
      waiting.stop();

      match = await playMatch({
        EngineClass: FakeSoloGame,
        gameId: "fake_solo",
        mode: "solo",
        script: hold("host", "ArrowRight"),
      });
      match.advance(3000);
      expect(match.results.host).toHaveLength(1);
      expect(match.engines.host.quit()).toBe(false);
      expect(match.results.host).toHaveLength(1);
      match.stop();
      match.restore();

      match = await play();
      match.advance(500);
      expect(match.engines.host.quit()).toBe(false);
      expect(match.engines.guest.quit()).toBe(false);
    });
  });

  describe("pausing a solo match", () => {
    it("holds the match still, lets go of held keys, and goes on where it stood", async () => {
      match = await playMatch({
        EngineClass: FakeGame,
        gameId: "fake",
        mode: "solo",
        script: hold("host", "ArrowRight"),
      });
      match.advance(200);
      const { host } = match.engines;

      expect(host.pause()).toBe(true);
      expect(host.pause()).toBe(false);
      expect(host.paused).toBe(true);
      expect(host.stepping).toBe(false);
      expect(Object.values(host.localInputs).some(Boolean)).toBe(false);
      const held = JSON.stringify(host.gameState);
      match.advance(1000);
      expect(JSON.stringify(host.gameState)).toBe(held);

      expect(host.resume()).toBe(true);
      expect(host.resume()).toBe(false);
      expect(host.paused).toBe(false);
      expect(host.stepping).toBe(true);
      match.advance(200);
      expect(JSON.stringify(host.gameState)).not.toBe(held);
    });

    it("never takes Esc: it goes on to the page's menu, through a match that holds every other key", () => {
      const game = new FakeGame(
        recordingCanvas(64, 48),
        createLocalTransport(),
        "fake",
        true,
        null,
        { mode: "solo" },
      );
      game.start();
      game.beginMatch();
      const page = vi.fn();
      window.addEventListener("keydown", page);

      window.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", cancelable: true }));
      expect(page).not.toHaveBeenCalled();
      const esc = new KeyboardEvent("keydown", { key: "Escape", cancelable: true });
      window.dispatchEvent(esc);
      expect(page).toHaveBeenCalledOnce();
      expect(esc.defaultPrevented).toBe(false);

      window.removeEventListener("keydown", page);
      game.stop();
    });

    it("ends a paused match when it is quit", async () => {
      match = await playMatch({
        EngineClass: FakeSoloGame,
        gameId: "fake_solo",
        mode: "solo",
        script: hold("host", "ArrowRight"),
      });
      match.advance(300);
      const { host } = match.engines;
      host.pause();

      expect(host.quit()).toBe(true);
      expect(host.paused).toBe(false);
      expect(match.results.host).toHaveLength(1);
    });

    it("holds nothing before the match begins or on either side of a P2P match", async () => {
      const waiting = new FakeGame(
        recordingCanvas(64, 48),
        createLocalTransport(),
        "fake",
        true,
        null,
        { mode: "solo" },
      );
      waiting.start();
      expect(waiting.pause()).toBe(false);
      waiting.stop();

      match = await play();
      match.advance(500);
      expect(match.engines.host.pause()).toBe(false);
      expect(match.engines.guest.pause()).toBe(false);
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
      const { host, guest } = match.engines;
      guest.transport.send(new Uint8Array([0x83, 9, 9, 2]).buffer);
      expect(host.ended).toBeUndefined();

      const sent = match.record().wire.length;
      host.gameState = null;
      host.broadcast();
      expect(match.record().wire.length).toBe(sent);
      host.gameState = { phase: PHASE.PLAYING, x: 0, score1: 0, score2: 0, countdown: 0 };
    });

    it("the host ignores a snapshot sent to it", async () => {
      match = await play();
      match.advance(400);
      const { host, guest } = match.engines;
      const before = { ...host.gameState };
      guest.transport.send(SNAPSHOT.encode({ ...before, x: before.x + 50, score2: 7 }));
      expect(host.gameState).toEqual(before);
    });

    it("the guest ignores a snapshot it cannot read", async () => {
      match = await play();
      match.advance(400);
      const { host, guest } = match.engines;
      const before = { ...guest.gameState };
      // The snapshot's type byte, and one byte of a body that needs more.
      host.transport.send(new Uint8Array([new Uint8Array(SNAPSHOT.encode(before))[0], 1]).buffer);
      expect(guest.gameState).toEqual(before);
    });

    it("a second start changes nothing", async () => {
      const started = vi.fn();
      match = await play({ EngineClass: defineGame({ ...definition, onStart: started }) });
      const calls = started.mock.calls.length; // the host's start and the guest's
      match.engines.host.start();
      expect(started).toHaveBeenCalledTimes(calls);
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
          if (!game.isHost && event.key === "x") game.sendInputEdge(7);
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
