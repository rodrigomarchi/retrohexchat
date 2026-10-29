import { describe, it, expect } from "vitest";
import {
  PHASE,
  GAME_MODE,
  ENEMY_TYPE,
  MAX_ENEMIES,
  MAX_FUEL,
  MAX_MINES,
  SNAPSHOT,
  GAME_END,
} from "../../../../js/lib/games/hex_raid/protocol.js";
import * as protocol from "../../../../js/lib/games/hex_raid/protocol.js";
import { createInitialState } from "../../../../js/lib/games/hex_raid/physics.js";
import {
  describeHandshake,
  describeTwoByteScoreEnd,
  itFramesMessages,
} from "../../../support/games/protocol_tests.js";

/** A snapshot of a match as it starts, with `overrides` on top. */
function snapshotState(overrides = {}) {
  return { ...createInitialState(GAME_MODE.RIVER_DUEL, 0), ...overrides };
}

describe("Hex Raid Protocol", () => {
  describe("game state encode/decode", () => {
    it("roundtrips a full state", () => {
      const state = {
        jet1X: 320,
        jet1Y: 400,
        jet1Speed: 2,
        jet1Fuel: 200,
        jet1Lives: 3,
        jet1Alive: true,
        jet1Invuln: false,
        jet1Respawning: false,
        jet2X: 280,
        jet2Y: 380,
        jet2Speed: 3,
        jet2Fuel: 150,
        jet2Lives: 2,
        jet2Alive: true,
        jet2Invuln: true,
        jet2Respawning: false,
        m1X: 320,
        m1Y: 300,
        m1Active: true,
        m2X: 280,
        m2Y: 310,
        m2Active: false,
        enemies: [
          { type: ENEMY_TYPE.BOAT, x: 300, y: 200, alive: true },
          { type: ENEMY_TYPE.HELI, x: 350, y: 150, alive: true },
          { type: ENEMY_TYPE.JET, x: 400, y: 100, alive: false },
        ],
        enemyCount: 3,
        fuels: [{ x: 310, y: 250, available: true }],
        fuelCount: 1,
        mines: [
          { x: 330, y: 350, owner: 1, active: true },
          { x: 270, y: 340, owner: 2, active: true },
        ],
        mineCount: 2,
        bridgeY: 50,
        bridgeHp: 3,
        bridgeActive: true,
        score1: 1200,
        score2: 980,
        phase: PHASE.FLYING,
        countdown: 0,
        section: 3,
        scrollY: 5400.5,
        mode: GAME_MODE.RIVER_DUEL,
        seed: 0xdeadbeef,
      };

      const buf = SNAPSHOT.encode(state);
      expect(buf.byteLength).toBe(185);

      const d = SNAPSHOT.decode(buf);
      expect(d).not.toBeNull();

      // Jets
      expect(d.jet1X).toBe(320);
      expect(d.jet1Y).toBe(400);
      expect(d.jet1Speed).toBe(2);
      expect(d.jet1Fuel).toBe(200);
      expect(d.jet1Lives).toBe(3);
      expect(d.jet1Alive).toBe(true);
      expect(d.jet1Invuln).toBe(false);
      expect(d.jet1Respawning).toBe(false);

      expect(d.jet2X).toBe(280);
      expect(d.jet2Y).toBe(380);
      expect(d.jet2Speed).toBe(3);
      expect(d.jet2Fuel).toBe(150);
      expect(d.jet2Lives).toBe(2);
      expect(d.jet2Alive).toBe(true);
      expect(d.jet2Invuln).toBe(true);
      expect(d.jet2Respawning).toBe(false);

      // Missiles
      expect(d.m1X).toBe(320);
      expect(d.m1Y).toBe(300);
      expect(d.m1Active).toBe(true);
      expect(d.m2X).toBe(280);
      expect(d.m2Y).toBe(310);
      expect(d.m2Active).toBe(false);

      // Enemies (3 active + 13 empty)
      expect(d.enemyCount).toBe(3);
      expect(d.enemies[0].type).toBe(ENEMY_TYPE.BOAT);
      expect(d.enemies[0].x).toBe(300);
      expect(d.enemies[0].y).toBe(200);
      expect(d.enemies[0].alive).toBe(true);
      expect(d.enemies[1].type).toBe(ENEMY_TYPE.HELI);
      expect(d.enemies[2].type).toBe(ENEMY_TYPE.JET);
      expect(d.enemies[2].alive).toBe(false);
      // Empty slots
      expect(d.enemies[3].type).toBe(0);
      expect(d.enemies[3].alive).toBe(false);

      // Fuel (1 active + 2 empty)
      expect(d.fuelCount).toBe(1);
      expect(d.fuels[0].x).toBe(310);
      expect(d.fuels[0].y).toBe(250);
      expect(d.fuels[0].available).toBe(true);
      expect(d.fuels[1].available).toBe(false);

      // Mines (2 active + 2 empty)
      expect(d.mineCount).toBe(2);
      expect(d.mines[0].x).toBe(330);
      expect(d.mines[0].owner).toBe(1);
      expect(d.mines[0].active).toBe(true);
      expect(d.mines[1].owner).toBe(2);
      expect(d.mines[2].active).toBe(false);

      // Bridge
      expect(d.bridgeY).toBe(50);
      expect(d.bridgeHp).toBe(3);
      expect(d.bridgeActive).toBe(true);

      // Meta
      expect(d.score1).toBe(1200);
      expect(d.score2).toBe(980);
      expect(d.phase).toBe(PHASE.FLYING);
      expect(d.countdown).toBe(0);
      expect(d.section).toBe(3);
      expect(d.scrollY).toBeCloseTo(5400.5, 1);
      expect(d.mode).toBe(GAME_MODE.RIVER_DUEL);
      expect(d.seed).toBe(0xdeadbeef);
    });

    it("handles zero entities", () => {
      const state = snapshotState({
        mode: GAME_MODE.PACIFIST,
      });

      const buf = SNAPSHOT.encode(state);
      const d = SNAPSHOT.decode(buf);
      expect(d.enemyCount).toBe(0);
      expect(d.fuelCount).toBe(0);
      expect(d.mineCount).toBe(0);
      expect(d.phase).toBe(PHASE.WAITING);
    });

    it("handles max entities", () => {
      const enemies = [];
      for (let i = 0; i < MAX_ENEMIES; i++) {
        enemies.push({
          type: ENEMY_TYPE.BOAT,
          x: 100 + i * 50,
          y: 100 + i * 20,
          alive: true,
        });
      }
      const fuels = [];
      for (let i = 0; i < MAX_FUEL; i++) {
        fuels.push({ x: 200 + i * 100, y: 300 + i * 50, available: true });
      }
      const mines = [];
      for (let i = 0; i < MAX_MINES; i++) {
        mines.push({
          x: 150 + i * 80,
          y: 400,
          owner: (i % 2) + 1,
          active: true,
        });
      }

      const state = snapshotState({
        jet1X: 320,
        jet1Y: 400,
        jet2X: 320,
        jet2Y: 400,
        enemies,
        enemyCount: MAX_ENEMIES,
        fuels,
        fuelCount: MAX_FUEL,
        mines,
        mineCount: MAX_MINES,
        bridgeY: 1000,
        bridgeHp: 3,
        bridgeActive: true,
        phase: PHASE.FLYING,
        countdown: 0,
        section: 1,
        mode: GAME_MODE.BLITZ,
        seed: 42,
      });

      const buf = SNAPSHOT.encode(state);
      const d = SNAPSHOT.decode(buf);
      expect(d.enemyCount).toBe(MAX_ENEMIES);
      expect(d.fuelCount).toBe(MAX_FUEL);
      expect(d.mineCount).toBe(MAX_MINES);

      for (let i = 0; i < MAX_ENEMIES; i++) {
        expect(d.enemies[i].alive).toBe(true);
        expect(d.enemies[i].x).toBe(100 + i * 50);
      }
    });

    it("handles respawning flag", () => {
      const state = snapshotState({
        jet1X: 320,
        jet1Y: 400,
        jet1Speed: 0,
        jet1Fuel: 100,
        jet1Lives: 2,
        jet1Alive: false,
        jet1Respawning: true,
        jet2X: 320,
        jet2Y: 400,
        jet2Fuel: 200,
        phase: PHASE.FLYING,
        countdown: 0,
        section: 1,
        seed: 1,
      });

      const d = SNAPSHOT.decode(SNAPSHOT.encode(state));
      expect(d.jet1Alive).toBe(false);
      expect(d.jet1Respawning).toBe(true);
      expect(d.jet2Alive).toBe(true);
      expect(d.jet2Respawning).toBe(false);
    });

    itFramesMessages(SNAPSHOT, { short: [10], length: 185, wrongType: 0x81 });

    it("roundtrips high scores (Uint16)", () => {
      const state = snapshotState({
        score1: 12340,
        score2: 65000,
        phase: PHASE.FINISHED,
        countdown: 0,
        section: 10,
        scrollY: 18000.0,
        seed: 0xffffffff,
      });

      const d = SNAPSHOT.decode(SNAPSHOT.encode(state));
      expect(d.score1).toBe(12340);
      expect(d.score2).toBe(65000);
      expect(d.section).toBe(10);
      expect(d.seed).toBe(0xffffffff);
    });
  });

  describeTwoByteScoreEnd(protocol);
  describeHandshake(protocol);

  describe("boundary values", () => {
    it("roundtrips max Uint16 values (65535)", () => {
      const state = snapshotState({
        jet1X: 65535,
        jet1Y: 65535,
        score1: 65535,
        score2: 65535,
      });
      const d = SNAPSHOT.decode(SNAPSHOT.encode(state));
      expect(d.jet1X).toBe(65535);
      expect(d.jet1Y).toBe(65535);
      expect(d.score1).toBe(65535);
      expect(d.score2).toBe(65535);
    });

    it("roundtrips max Uint8 values (255)", () => {
      const state = snapshotState({
        jet1Speed: 255,
        jet1Fuel: 255,
        jet1Lives: 255,
        countdown: 255,
        section: 255,
      });
      const d = SNAPSHOT.decode(SNAPSHOT.encode(state));
      expect(d.jet1Speed).toBe(255);
      expect(d.jet1Fuel).toBe(255);
      expect(d.jet1Lives).toBe(255);
      expect(d.countdown).toBe(255);
      expect(d.section).toBe(255);
    });

    it("roundtrips all PHASE values", () => {
      const phases = [PHASE.WAITING, PHASE.COUNTDOWN, PHASE.FLYING, PHASE.FINISHED];
      for (const phase of phases) {
        const state = snapshotState({ phase });
        const d = SNAPSHOT.decode(SNAPSHOT.encode(state));
        expect(d.phase).toBe(phase);
      }
    });

    it("roundtrips all GAME_MODE values", () => {
      const modes = [GAME_MODE.RIVER_DUEL, GAME_MODE.PACIFIST, GAME_MODE.BLITZ];
      for (const mode of modes) {
        const state = snapshotState({ mode });
        const d = SNAPSHOT.decode(SNAPSHOT.encode(state));
        expect(d.mode).toBe(mode);
      }
    });

    it("roundtrips negative scrollY", () => {
      const state = snapshotState({ scrollY: -100.5 });
      const d = SNAPSHOT.decode(SNAPSHOT.encode(state));
      expect(d.scrollY).toBeCloseTo(-100.5, 1);
    });

    it("roundtrips very large scrollY", () => {
      const state = snapshotState({ scrollY: 100000.0 });
      const d = SNAPSHOT.decode(SNAPSHOT.encode(state));
      expect(d.scrollY).toBeCloseTo(100000.0, 0);
    });

    it("roundtrips game end with max Uint16 scores", () => {
      const result = { score1: 65535, score2: 65535, winner: 2 };
      const d = GAME_END.decode(GAME_END.encode(result));
      expect(d.score1).toBe(65535);
      expect(d.score2).toBe(65535);
      expect(d.winner).toBe(2);
    });

    it("roundtrips game end with zero scores", () => {
      const result = { score1: 0, score2: 0, winner: 0 };
      const d = GAME_END.decode(GAME_END.encode(result));
      expect(d.score1).toBe(0);
      expect(d.score2).toBe(0);
      expect(d.winner).toBe(0);
    });
  });
});
