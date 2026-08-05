import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { startMatch, dropFirst, messageType } from "../../helpers/game_match.js";
import { BASE_MSG } from "../../../js/lib/games/net_protocol.js";
import { SurroundEngine } from "../../../js/lib/games/surround/engine.js";
import { WarlordEngine } from "../../../js/lib/games/warlords/engine.js";
import { PixelTanksEngine } from "../../../js/lib/games/pixel_tanks/engine.js";
import { HexHockeyEngine } from "../../../js/lib/games/hex_hockey/engine.js";
import { PongEngine } from "../../../js/lib/games/pong/engine.js";

/** Press a key on an engine the way the document listener would. */
function press(engine, key) {
  engine._onKeyDown({ key, repeat: false, target: null, preventDefault: () => {} });
}

function release(engine, key) {
  engine._onKeyUp({ key, repeat: false, target: null, preventDefault: () => {} });
}

describe("P2P match", () => {
  let match;

  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    match?.stop();
    match = null;
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  // Both sides ran the same match very differently: the guest drew only when a
  // snapshot landed, so its frame rate was the host's send rate.
  describe("both peers draw", () => {
    it("gives the guest its own frame rate, not the host's send rate", () => {
      match = startMatch(PongEngine, "hex_pong");

      match.advance(200);

      // Drive straight into a rally: the phase machine's own pauses would make
      // "how many frames in a second" depend on when a point happened to land.
      match.host.gameState = { ...match.host.gameState, phase: 3, ballVX: 4, ballVY: 2 };
      match.host._startGameLoop();
      match.advance(200);
      expect(match.host.stepping).toBe(true);

      const paints = { host: 0, guest: 0 };
      for (const side of ["host", "guest"]) {
        const engine = match[side];
        const draw = engine._renderState.bind(engine);
        engine._renderState = () => {
          paints[side] += 1;
          draw();
        };
      }

      match.advance(1000);

      // A second of play is a second of frames on both sides. The guest used to
      // draw at the host's send rate, which is what made it look broken.
      expect(paints.host).toBeGreaterThan(45);
      expect(paints.guest).toBeGreaterThan(45);
      expect(paints.guest).toBeGreaterThan(paints.host * 0.8);
    });

    it("starts the match without either side hanging", () => {
      match = startMatch(PongEngine, "hex_pong");
      match.advance(3000);

      expect(match.host.peerReady).toBe(true);
    });

    it("still starts when the first ready datagrams are lost", () => {
      // The channel does not retransmit, and nothing else restates this
      // message. On loopback a single send always arrives, which is exactly how
      // a hung match hides until it reaches real Wi-Fi.
      match = startMatch(PongEngine, "hex_pong", { drop: dropFirst(3) });
      match.advance(3000);

      expect(match.host.peerReady).toBe(true);
    });
  });

  // Light Trails is the only game whose input is a discrete command rather than
  // a held key: there is no later datagram restating a turn.
  describe("Light Trails — discrete input", () => {
    it("delivers a turn from the guest to the host", () => {
      match = startMatch(SurroundEngine, "light_trails");
      match.advance(200);

      press(match.guest, "ArrowUp");
      match.advance(100);

      expect(match.host.p2PendingDir).toBe(0);
    });

    it("survives losing copies of the turn", () => {
      match = startMatch(SurroundEngine, "light_trails", {
        drop: dropFirst(2, (data) => messageType(data) === BASE_MSG.INPUT_EDGE),
      });
      match.advance(200);

      press(match.guest, "ArrowLeft");
      match.advance(300);

      // Two of the three redundant copies were dropped; the third carries it.
      expect(match.host.p2PendingDir).toBe(2);
    });

    it("applies a repeated command only once", () => {
      match = startMatch(SurroundEngine, "light_trails");
      match.advance(200);

      const applied = [];
      match.host._handleRemoteEdge = (code) => applied.push(code);

      press(match.guest, "ArrowRight");
      match.advance(300);

      expect(applied).toEqual([3]);
    });

    it("moves the grid at 10Hz off the 60Hz clock", () => {
      match = startMatch(SurroundEngine, "light_trails");
      match.advance(200);

      const ticks = [];
      match.host._tickLoop = () => ticks.push(1);
      match.host._startTickLoop();
      match.advance(1000);

      // Six fixed steps per grid move: ten moves a second, whatever the display.
      expect(ticks.length).toBeGreaterThanOrEqual(8);
      expect(ticks.length).toBeLessThanOrEqual(12);
    });
  });

  // The catch mechanic fires when the guest *releases* space. It lived inside
  // the input branch that the level-triggered transport replaced.
  describe("Hex Warlords — release-triggered launch", () => {
    it("lets the guest launch a fireball it caught", () => {
      match = startMatch(WarlordEngine, "hex_warlords");
      match.advance(200);

      match.host.gameState.caughtBy = 2;
      match.host.gameState.fireballSpeed = 3;

      press(match.guest, " ");
      match.advance(100);
      expect(match.host.gameState.caughtBy).toBe(2);

      release(match.guest, " ");
      match.advance(100);

      expect(match.host.gameState.caughtBy).toBe(0);
    });

    it("does not launch while the guest keeps holding", () => {
      match = startMatch(WarlordEngine, "hex_warlords");
      match.advance(200);
      match.host.gameState.caughtBy = 2;

      press(match.guest, " ");
      match.advance(500);

      expect(match.host.gameState.caughtBy).toBe(2);
    });
  });

  // These games cancelled the base frame loop inside _startGameLoop, freezing
  // the canvas the moment play began, and animate their round-over pause.
  describe("Pixel Tanks — pause animation and loop survival", () => {
    it("keeps drawing once the match starts", () => {
      match = startMatch(PixelTanksEngine, "pixel_tanks");
      match.advance(200);

      const before = match.host._telemetry._frames;
      match.host._startGameLoop();
      match.advance(500);

      expect(match.host._telemetry._frames).toBeGreaterThan(before + 10);
      expect(match.host.stepping).toBe(true);
    });

    it("settles round-over particles on the fixed clock", () => {
      match = startMatch(PixelTanksEngine, "pixel_tanks");
      match.advance(200);

      match.host._stopSteps();
      match.host.particles = Array.from({ length: 30 }, () => ({
        x: 100,
        y: 100,
        vx: 1,
        vy: 1,
        life: 20,
      }));

      const before = match.host.particles.length;
      match.advance(500);

      // They must drain rather than freeze, and the loop keeps drawing them.
      expect(match.host.particles.length).toBeLessThan(before);
    });
  });

  // The goal flash counts down in simulation frames. Decaying it on paint tied
  // it to the display: a 120Hz panel lost the flash twice as fast.
  describe("Hex Hockey — flash decays on the clock, not the paint", () => {
    it("decays once per step regardless of how often it paints", () => {
      match = startMatch(HexHockeyEngine, "hex_hockey");
      match.advance(200);

      match.host._startSteps();
      match.host.goalFlash = 60;

      for (let i = 0; i < 10; i++) match.host._gameLoop();

      expect(match.host.goalFlash).toBe(50);
    });

    it("does not decay when only drawing", () => {
      match = startMatch(HexHockeyEngine, "hex_hockey");
      match.advance(200);

      match.host.goalFlash = 30;
      for (let i = 0; i < 20; i++) match.host._renderState();

      expect(match.host.goalFlash).toBe(30);
    });
  });
});
