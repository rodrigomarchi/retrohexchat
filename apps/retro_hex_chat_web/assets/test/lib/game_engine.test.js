import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { GameEngine, SEND_HIGH_WATER_BYTES } from "../../js/lib/game_engine.js";
import { i16, schema, u8 } from "../../js/lib/games/core/codec.js";
import { defineGame } from "../../js/lib/games/core/define_game.js";
import { MSG } from "../../js/lib/games/core/messages.js";
import { FIXED_STEP_MS } from "../../js/lib/games/frame_clock.js";
import { decodeInputState, encodeInputState, packInputs } from "../../js/lib/games/net_protocol.js";
import { createLocalTransport } from "../../js/lib/games/transport.js";
import { fakeChannel } from "../support/games/fake_channel.js";
import { playMatch } from "../support/games/harness.js";

/*
 * What the engine underneath every game does — the clock, the paint, the
 * wire, the ready handshake, the keyboard — seen from outside, through the
 * smallest game a definition can describe.
 */

const PHASE = { WAITING: 0, PLAYING: 1, OVER: 2 };
const SNAPSHOT = schema(MSG.GAME_STATE, [u8("phase"), i16("x"), u8("score")]);
const END = schema(MSG.GAME_END, [u8("winner")]);

/** A game with two held keys and one smoothed coordinate, and a record of what reached it. */
function probe(overrides = {}) {
  const seen = { ticks: 0, idles: 0, paints: 0, keys: [], edges: [] };
  const Game = defineGame({
    inputs: { up: ["ArrowUp"], down: ["ArrowDown"] },
    interpolate: { keys: ["x"] },
    schema: { snapshot: SNAPSHOT, end: END },
    init: () => ({ phase: PHASE.WAITING, x: 0, score: 0 }),
    flow: {
      phases: PHASE,
      initial: "WAITING",
      begin: "PLAYING",
      states: {
        PLAYING: { tick: () => (seen.ticks += 1) },
        OVER: { final: true },
      },
    },
    idle: () => (seen.idles += 1),
    render: () => (seen.paints += 1),
    onKeyDown: (_game, event) => seen.keys.push(event.key),
    onRemoteEdge: (_game, code) => seen.edges.push(code),
    disconnectResult: () => ({}),
    ...overrides,
  });
  return { Game, seen };
}

const snapshot = (fields) => SNAPSHOT.encode({ phase: PHASE.PLAYING, x: 0, score: 0, ...fields });
const typeOf = (buf) => new Uint8Array(buf)[0];
const sentOf = (channel, type) => channel.sent.filter((buf) => typeOf(buf) === type);
const wireOf = (match, dir, type) =>
  match
    .record()
    .wire.filter((entry) => entry.dir === dir && parseInt(entry.hex.slice(0, 2), 16) === type);
const bytesOf = (hex) => new Uint8Array(hex.match(/../g).map((b) => parseInt(b, 16))).buffer;

describe("GameEngine", () => {
  let engines;
  let match;

  /** An engine on a channel the test holds, reading keys from the window. */
  function build(Game, { channel = fakeChannel(), isHost = true, options = {} } = {}) {
    const canvas = document.createElement("canvas");
    canvas.getContext = () => ({});
    const engine = new Game(canvas, channel, "probe", isHost, null, options);
    engines.push(engine);
    return engine;
  }

  /** Fire one key event at `target` and hand it back. */
  function press(target, key, init = {}) {
    const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...init });
    target.dispatchEvent(event);
    return event;
  }

  beforeEach(() => {
    engines = [];
    vi.useFakeTimers({
      now: 0,
      toFake: [
        "setTimeout",
        "clearTimeout",
        "setInterval",
        "clearInterval",
        "Date",
        "performance",
        "requestAnimationFrame",
        "cancelAnimationFrame",
      ],
    });
  });

  afterEach(() => {
    for (const engine of engines) engine.stop();
    match?.stop();
    match?.restore();
    match = null;
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  describe("sending", () => {
    it("keeps the transport and the mode it was given", () => {
      const engine = build(probe().Game, { options: { mode: "solo" } });

      expect(engine.transport.kind).toBe("p2p");
      expect(engine.channel).toBe(engine.transport);
      expect(engine.mode).toBe("solo");
    });

    it("tags its telemetry with a local transport's own state", () => {
      const engine = build(probe().Game, {
        channel: createLocalTransport(),
        options: { mode: "solo" },
      });
      const samples = [];
      engine.onTelemetry = (sample) => samples.push(sample);
      engine.start();

      vi.advanceTimersByTime(5100);

      expect(samples.at(-1).channel_state).toBe("local");
    });

    it("sends a snapshot while the channel is open", () => {
      const channel = fakeChannel();
      build(probe().Game, { channel }).broadcast();
      expect(sentOf(channel, MSG.GAME_STATE)).toHaveLength(1);
    });

    it.each(["closing", "closed"])("sends nothing on a %s channel", (readyState) => {
      const channel = fakeChannel();
      channel.readyState = readyState;
      build(probe().Game, { channel }).broadcast();
      expect(channel.sent).toHaveLength(0);
    });

    it("survives a channel that closes during the send", () => {
      const channel = fakeChannel();
      channel.send = () => {
        throw new Error("closing");
      };
      vi.spyOn(console, "debug").mockImplementation(() => {});
      const engine = build(probe().Game, { channel });
      const samples = [];
      engine.onTelemetry = (sample) => samples.push(sample);
      engine.start();

      expect(() => engine.broadcast()).not.toThrow();

      // A snapshot that never left is not counted as sent.
      vi.advanceTimersByTime(5100);
      expect(samples.at(-1).bytes_out).toBe(0);
    });

    it("drops a snapshot once the channel is backed up", () => {
      const channel = fakeChannel();
      channel.bufferedAmount = SEND_HIGH_WATER_BYTES;

      // Queuing behind a backlog only adds latency the game never recovers
      // from, and the next snapshot supersedes this one anyway.
      build(probe().Game, { channel }).broadcast();

      expect(channel.sent).toHaveLength(0);
    });

    it("repeats a one-shot command, because the channel is unreliable", () => {
      const channel = fakeChannel();
      const guest = build(probe().Game, { channel, isHost: false });
      guest.start();

      guest.sendInputEdge(2);
      expect(sentOf(channel, MSG.INPUT_EDGE)).toHaveLength(1);

      vi.advanceTimersByTime(200);
      expect(sentOf(channel, MSG.INPUT_EDGE)).toHaveLength(3);
    });

    it("stops repeating once the engine is torn down", () => {
      const channel = fakeChannel();
      const guest = build(probe().Game, { channel, isHost: false });
      guest.start();

      guest.sendInputEdge(2);
      guest.stop();
      expect(vi.getTimerCount()).toBe(0);
      vi.advanceTimersByTime(200);

      expect(sentOf(channel, MSG.INPUT_EDGE)).toHaveLength(1);
    });
  });

  describe("ready handshake", () => {
    it("keeps announcing until the host answers", () => {
      const channel = fakeChannel();
      build(probe().Game, { channel, isHost: false }).start();
      expect(sentOf(channel, MSG.GAME_READY)).toHaveLength(1);

      // Nothing else restates this message, and the host does nothing until it
      // lands — a single send would hang the match on one dropped datagram.
      vi.advanceTimersByTime(1000);
      expect(sentOf(channel, MSG.GAME_READY).length).toBeGreaterThan(3);
    });

    it("stops announcing on the first word from the host", () => {
      const channel = fakeChannel();
      build(probe().Game, { channel, isHost: false }).start();

      channel.emit("message", { data: snapshot({}) });
      const afterAnswer = sentOf(channel, MSG.GAME_READY).length;
      vi.advanceTimersByTime(2000);

      expect(sentOf(channel, MSG.GAME_READY)).toHaveLength(afterAnswer);
    });

    it("never announces from the host side", () => {
      const channel = fakeChannel();
      build(probe().Game, { channel }).start();

      vi.advanceTimersByTime(2000);

      expect(channel.sent).toHaveLength(0);
    });

    it("stops announcing once the engine is torn down", () => {
      const channel = fakeChannel();
      const guest = build(probe().Game, { channel, isHost: false });
      guest.start();
      guest.stop();
      expect(vi.getTimerCount()).toBe(0);

      const afterStop = sentOf(channel, MSG.GAME_READY).length;
      vi.advanceTimersByTime(2000);

      expect(sentOf(channel, MSG.GAME_READY)).toHaveLength(afterStop);
    });
  });

  describe("input transport", () => {
    const masksFromGuest = () =>
      wireOf(match, "guest>host", MSG.INPUT_STATE).map((entry) =>
        decodeInputState(bytesOf(entry.hex)),
      );

    async function paired(overrides) {
      const { Game, seen } = probe(overrides);
      match = await playMatch({ EngineClass: Game, gameId: "probe" });
      match.advance(100);
      return seen;
    }

    it("sends the full held mask, not one message per key", async () => {
      const { Game } = probe();
      await paired();
      match.key("guest", "ArrowUp");
      match.key("guest", "ArrowDown");
      match.advance(50);

      expect(masksFromGuest().at(-1).mask).toBe(
        packInputs({ up: true, down: true }, Game.INPUT_BITS),
      );
    });

    it("restates a held mask every step", async () => {
      await paired();
      match.key("guest", "ArrowUp");
      const before = masksFromGuest().length;

      match.advance(1000);

      // Losing one datagram must cost a step of staleness, never a stuck key.
      expect(masksFromGuest().length - before).toBeGreaterThanOrEqual(55);
    });

    it("stops restating an empty mask once the release has been repeated", async () => {
      await paired();
      match.key("guest", "ArrowUp");
      match.advance(100);
      match.key("guest", "ArrowUp", "keyup");
      const before = masksFromGuest().length;

      match.advance(1000);

      // The release is restated a few times, then the guest goes quiet.
      const restated = masksFromGuest().length - before;
      expect(restated).toBeGreaterThan(0);
      expect(restated).toBeLessThan(20);
    });

    it("says nothing when no key was ever held", async () => {
      await paired();
      match.advance(1000);

      // The host already assumes everything is released.
      expect(masksFromGuest()).toHaveLength(0);
    });

    it("never sends input from the host", async () => {
      await paired();
      match.key("host", "ArrowUp");
      match.advance(1000);

      expect(wireOf(match, "host>guest", MSG.INPUT_STATE)).toHaveLength(0);
    });

    it("hands the guest's held keys to the host", async () => {
      await paired();
      match.key("guest", "ArrowUp");
      match.advance(50);

      expect(match.engines.host.remoteInputs).toEqual({ up: true, down: false });
    });

    it("ignores a mask that arrived out of order", async () => {
      await paired();
      match.send("guest", encodeInputState(5, 0b11));
      match.send("guest", encodeInputState(4, 0b00));
      match.advance(1);

      // Unordered delivery means stale input can land after fresh input.
      expect(match.engines.host.remoteInputs).toEqual({ up: true, down: true });
    });

    it("applies each discrete command once, however often it is repeated", async () => {
      const seen = await paired();
      match.engines.guest.sendInputEdge(2);
      match.advance(200);

      expect(seen.edges).toEqual([2]);
    });
  });

  describe("keyboard", () => {
    afterEach(() => {
      window.dispatchEvent(new KeyboardEvent("keyup", { key: "ArrowUp", bubbles: true }));
    });

    /** Record keydowns reaching the page's own window listener while `run` runs. */
    function pageSees(run) {
      const page = vi.fn();
      window.addEventListener("keydown", page);
      try {
        run();
      } finally {
        window.removeEventListener("keydown", page);
      }
      return page;
    }

    it("ignores auto-repeat", () => {
      const { Game, seen } = probe();
      build(Game, { isHost: false }).start();

      press(window, "ArrowUp");
      press(window, "ArrowUp", { repeat: true });

      expect(seen.keys).toEqual(["ArrowUp"]);
    });

    it("leaves keystrokes aimed at a text field alone", () => {
      const { Game, seen } = probe();
      build(Game, { isHost: false }).start();

      // The game runs in a window beside the chat composer.
      const editable = document.createElement("div");
      editable.setAttribute("contenteditable", "true");
      const fields = [document.createElement("input"), editable, document.createElement("select")];
      for (const field of fields) {
        document.body.appendChild(field);
        press(field, "ArrowUp");
        field.remove();
      }

      expect(seen.keys).toEqual([]);
    });

    it("leaves the keyboard alone for somebody only watching", () => {
      const { Game, seen } = probe();
      const watching = build(Game, { isHost: false, options: { mode: "spectator" } });
      watching.setKeyboardCaptured(true);
      watching.start();

      const page = pageSees(() => press(window, "ArrowUp"));

      expect(seen.keys).toEqual([]);
      expect(page).toHaveBeenCalledOnce();
    });

    it("stops a game key it handled before it reaches the page's shortcuts", () => {
      build(probe().Game, { isHost: false }).start();

      const page = pageSees(() => press(window, "ArrowUp"));

      expect(page).not.toHaveBeenCalled();
    });

    it("takes every key first while a match holds the keyboard", () => {
      const { Game, seen } = probe();
      const engine = build(Game, { isHost: false });
      engine.setKeyboardCaptured(true);
      engine.start();

      const page = pageSees(() => press(window, "ArrowRight"));

      expect(seen.keys).toEqual(["ArrowRight"]);
      expect(page).not.toHaveBeenCalled();
    });

    it("lets a key that is not the game's reach the page", () => {
      build(probe().Game, { isHost: false }).start();

      const page = pageSees(() => press(document, "Meta"));

      expect(page).toHaveBeenCalledOnce();
    });

    it("lets typing reach the page even while a match holds the keyboard", () => {
      const { Game, seen } = probe();
      const engine = build(Game, { isHost: false });
      engine.setKeyboardCaptured(true);
      engine.start();
      const input = document.createElement("input");
      document.body.appendChild(input);

      const page = pageSees(() => press(input, "ArrowUp"));
      input.remove();

      expect(seen.keys).toEqual([]);
      expect(page).toHaveBeenCalledOnce();
    });
  });

  describe("presentation loop", () => {
    it("runs no simulation steps before the match begins, only idle ones", () => {
      const { Game, seen } = probe();
      build(Game).start();

      vi.advanceTimersByTime(FIXED_STEP_MS * 4);

      expect(seen.ticks).toBe(0);
      expect(seen.idles).toBeGreaterThan(0);
    });

    it("runs one step per step duration once the match begins", () => {
      const { Game, seen } = probe();
      const host = build(Game);
      host.start();
      host.beginMatch();

      vi.advanceTimersByTime(1000);

      expect(seen.ticks).toBeGreaterThanOrEqual(59);
      expect(seen.ticks).toBeLessThanOrEqual(61);
    });

    it("paints once per frame however many repaints were asked for", () => {
      const { Game, seen } = probe();
      const host = build(Game);
      host.start();
      vi.advanceTimersByTime(20);
      const before = seen.paints;

      host.invalidate();
      host.invalidate();
      vi.advanceTimersByTime(17);

      expect(seen.paints).toBe(before + 1);
    });

    it("keeps painting the guest while a snapshot is being interpolated", () => {
      const { Game, seen } = probe();
      const channel = fakeChannel();
      build(Game, { channel, isHost: false }).start();
      vi.advanceTimersByTime(20);

      channel.emit("message", { data: snapshot({ x: 0 }) });
      channel.emit("message", { data: snapshot({ x: 40 }) });
      const before = seen.paints;

      // No new snapshot arrives, and the guest still has frames to draw.
      vi.advanceTimersByTime(50);

      expect(seen.paints).toBeGreaterThan(before + 1);
    });
  });

  describe("a snapshot on the guest", () => {
    it("lands the fields that are not motion at once", () => {
      const channel = fakeChannel();
      const guest = build(probe().Game, { channel, isHost: false });
      guest.start();

      channel.emit("message", { data: snapshot({ x: 100, score: 7 }) });

      expect(guest.gameState.score).toBe(7);
    });

    it("lands through the game's own applier when it has one", () => {
      const channel = fakeChannel();
      const { Game } = probe({
        applySnapshot: (game, decoded) => {
          game.gameState = { ...game.gameState, ...decoded, applied: true };
        },
      });
      const guest = build(Game, { channel, isHost: false });
      guest.start();

      channel.emit("message", { data: snapshot({ x: 10 }) });

      expect(guest.gameState.applied).toBe(true);
    });
  });

  describe("stop", () => {
    it("releases the game's AudioContext", () => {
      const engine = build(probe().Game);
      engine.audio = { dispose: vi.fn() };
      engine.start();
      engine.stop();

      // Each context holds a real-time audio thread, and browsers cap how many
      // a page may open.
      expect(engine.audio.dispose).toHaveBeenCalledOnce();
    });

    it("tolerates a game whose audio has no teardown", () => {
      const engine = build(probe().Game);
      engine.audio = {};
      engine.start();
      expect(() => engine.stop()).not.toThrow();
    });

    it("stops the simulation and the frame loop", () => {
      const { Game, seen } = probe();
      const host = build(Game);
      host.start();
      host.beginMatch();
      host.stop();

      // No frame or timer is left to run.
      expect(vi.getTimerCount()).toBe(0);
      vi.advanceTimersByTime(1000);

      expect(seen.ticks).toBe(0);
      expect(host.stepping).toBe(false);
    });
  });

  // A game the server knows and this page's scripts do not (a page loaded
  // before a release) gets the bare engine: it says so instead of a blank canvas.
  describe("a game this page has no code for", () => {
    it("says the game is not here yet", () => {
      vi.stubGlobal("getComputedStyle", () => ({ getPropertyValue: () => "" }));
      const ctx = { fillRect: vi.fn(), fillText: vi.fn(), strokeRect: vi.fn() };
      const canvas = { width: 640, height: 480, getContext: () => ctx };
      const engine = new GameEngine(canvas, fakeChannel(), "hex_new", false);
      engines.push(engine);
      engine.start();

      vi.advanceTimersByTime(20);

      const texts = ctx.fillText.mock.calls.map(([text]) => text);
      expect(texts).toContain("HEX NEW");
      expect(texts).toContain("Game implementation coming soon!");
      vi.unstubAllGlobals();
    });
  });
});
