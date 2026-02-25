import { describe, it, expect } from "vitest";
import {
  CANVAS_W,
  CANVAS_H,
  INITIAL_LIVES,
  INITIAL_FUEL,
  BRIDGE_HP,
  SCORE_BOAT,
  SCORE_HELI,
  SCORE_JET,
  SCORE_BRIDGE,
  SCORE_MINE_HIT,
  mulberry32,
  getBankAtWorld,
  getRiverWidthAtScroll,
  getDifficulty,
  spawnEntities,
  createInitialState,
  moveJet,
  fireMissile,
  deployMine,
  updateScroll,
  updateEnemies,
  updateFuels,
  updateBridge,
  drainFuel,
  checkMissileHits,
  checkBridgeHits,
  checkFuelCapture,
  checkMineCollisions,
  checkBridgeCollision,
  checkRiverCollision,
  handleDeath,
  processRespawns,
  checkGameOver,
  getWinner,
  tickTimers,
  clearEvents,
  getMineCooldown,
} from "../../../../js/lib/games/hex_raid/physics.js";
import {
  PHASE,
  GAME_MODE,
  ENEMY_TYPE,
  MAX_ENEMIES,
} from "../../../../js/lib/games/hex_raid/protocol.js";

describe("Hex Raid Physics", () => {
  describe("mulberry32 PRNG", () => {
    it("is deterministic — same seed produces same sequence", () => {
      const rng1 = mulberry32(12345);
      const rng2 = mulberry32(12345);
      for (let i = 0; i < 100; i++) {
        expect(rng1()).toBe(rng2());
      }
    });

    it("produces values in [0, 1)", () => {
      const rng = mulberry32(42);
      for (let i = 0; i < 1000; i++) {
        const v = rng();
        expect(v).toBeGreaterThanOrEqual(0);
        expect(v).toBeLessThan(1);
      }
    });

    it("different seeds produce different sequences", () => {
      const rng1 = mulberry32(1);
      const rng2 = mulberry32(2);
      const vals1 = Array.from({ length: 10 }, () => rng1());
      const vals2 = Array.from({ length: 10 }, () => rng2());
      expect(vals1).not.toEqual(vals2);
    });

    it("handles seed 0", () => {
      const rng = mulberry32(0);
      expect(rng()).toBeGreaterThanOrEqual(0);
    });

    it("handles max seed (0xFFFFFFFF)", () => {
      const rng = mulberry32(0xffffffff);
      const v = rng();
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThan(1);
      expect(Number.isNaN(v)).toBe(false);
    });
  });

  describe("getRiverWidthAtScroll", () => {
    it("returns wider river at start, narrower later", () => {
      const w0 = getRiverWidthAtScroll(0, GAME_MODE.RIVER_DUEL);
      const w10k = getRiverWidthAtScroll(10000, GAME_MODE.RIVER_DUEL);
      const w25k = getRiverWidthAtScroll(25000, GAME_MODE.RIVER_DUEL);
      expect(w0).toBeGreaterThan(w10k);
      expect(w10k).toBeGreaterThan(w25k);
    });

    it("BLITZ mode starts narrower", () => {
      const normalW = getRiverWidthAtScroll(0, GAME_MODE.RIVER_DUEL);
      const blitzW = getRiverWidthAtScroll(0, GAME_MODE.BLITZ);
      expect(blitzW).toBeLessThan(normalW);
    });
  });

  describe("getBankAtWorld", () => {
    it("returns valid bank edges (leftX < rightX)", () => {
      const bank = getBankAtWorld(500, 42, GAME_MODE.RIVER_DUEL);
      expect(bank.leftX).toBeLessThan(bank.rightX);
      expect(bank.leftX).toBeGreaterThanOrEqual(0);
      expect(bank.rightX).toBeLessThanOrEqual(CANVAS_W);
    });

    it("is deterministic — same inputs produce same result", () => {
      const b1 = getBankAtWorld(1234, 42, GAME_MODE.RIVER_DUEL);
      const b2 = getBankAtWorld(1234, 42, GAME_MODE.RIVER_DUEL);
      expect(b1.leftX).toBe(b2.leftX);
      expect(b1.rightX).toBe(b2.rightX);
    });

    it("different seeds produce different banks", () => {
      const b1 = getBankAtWorld(500, 42, GAME_MODE.RIVER_DUEL);
      const b2 = getBankAtWorld(500, 99, GAME_MODE.RIVER_DUEL);
      // Banks should differ (with overwhelmingly high probability)
      expect(b1.leftX === b2.leftX && b1.rightX === b2.rightX).toBe(false);
    });

    it("produces smooth transitions (adjacent positions are close)", () => {
      const b1 = getBankAtWorld(1000, 42, GAME_MODE.RIVER_DUEL);
      const b2 = getBankAtWorld(1001, 42, GAME_MODE.RIVER_DUEL);
      // Adjacent positions should be within a few pixels
      expect(Math.abs(b1.leftX - b2.leftX)).toBeLessThan(5);
      expect(Math.abs(b1.rightX - b2.rightX)).toBeLessThan(5);
    });

    it("handles worldY = 0", () => {
      const bank = getBankAtWorld(0, 42, GAME_MODE.RIVER_DUEL);
      expect(bank.leftX).toBeDefined();
      expect(bank.rightX).toBeDefined();
    });

    it("handles very large worldY", () => {
      const bank = getBankAtWorld(100000, 42, GAME_MODE.RIVER_DUEL);
      expect(bank.leftX).toBeLessThan(bank.rightX);
    });
  });

  describe("getDifficulty", () => {
    it("returns increasing difficulty over distance", () => {
      const d0 = getDifficulty(0, GAME_MODE.RIVER_DUEL);
      const d10k = getDifficulty(10000, GAME_MODE.RIVER_DUEL);
      const d25k = getDifficulty(25000, GAME_MODE.RIVER_DUEL);

      // Enemy interval decreases (more frequent spawns)
      expect(d0.enemyInterval).toBeGreaterThan(d10k.enemyInterval);
      expect(d10k.enemyInterval).toBeGreaterThan(d25k.enemyInterval);

      // Fuel interval increases (less frequent fuel)
      expect(d0.fuelInterval).toBeLessThan(d10k.fuelInterval);

      // Enemy speed increases
      expect(d0.enemySpeed).toBeLessThan(d25k.enemySpeed);

      // River narrows
      expect(d0.riverWidth).toBeGreaterThan(d25k.riverWidth);
    });

    it("BLITZ mode is harder at same scrollY", () => {
      const normal = getDifficulty(0, GAME_MODE.RIVER_DUEL);
      const blitz = getDifficulty(0, GAME_MODE.BLITZ);
      // Blitz adds 5000 to distance, so should be harder
      expect(blitz.enemyInterval).toBeLessThan(normal.enemyInterval);
      expect(blitz.riverWidth).toBeLessThan(normal.riverWidth);
    });
  });

  describe("spawnEntities", () => {
    it("spawns enemies when scrollY passes threshold", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, scrollY: 400, nextEnemySpawnDist: 300 };
      const result = spawnEntities(state);
      expect(result.enemies.length).toBeGreaterThan(0);
      expect(result.nextEnemySpawnDist).toBeGreaterThan(300);
    });

    it("does not spawn when scrollY has not reached threshold", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, scrollY: 100, nextEnemySpawnDist: 300 };
      const result = spawnEntities(state);
      expect(result.enemies.length).toBe(0);
    });

    it("spawns fuel depots", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, scrollY: 600, nextFuelSpawnDist: 500 };
      const result = spawnEntities(state);
      expect(result.fuels.length).toBeGreaterThan(0);
    });

    it("spawns bridge when threshold reached and no active bridge", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        phase: PHASE.FLYING,
        scrollY: 2100,
        nextBridgeSpawnDist: 2000,
        bridgeActive: false,
      };
      const result = spawnEntities(state);
      expect(result.bridgeActive).toBe(true);
      expect(result.bridgeHp).toBe(BRIDGE_HP);
    });

    it("does not spawn bridge when one is already active", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        phase: PHASE.FLYING,
        scrollY: 2100,
        nextBridgeSpawnDist: 2000,
        bridgeActive: true,
        bridgeHp: 3,
      };
      const result = spawnEntities(state);
      expect(result.bridgeActive).toBe(true);
    });

    it("does not spawn enemies past MAX_ENEMIES", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      const fullEnemies = Array.from({ length: MAX_ENEMIES }, (_, i) => ({
        type: ENEMY_TYPE.BOAT,
        x: 300 + i,
        y: 200,
        alive: true,
        vx: 0,
      }));
      state = {
        ...state,
        phase: PHASE.FLYING,
        scrollY: 5000,
        nextEnemySpawnDist: 100,
        enemies: fullEnemies,
        enemyCount: MAX_ENEMIES,
      };
      const result = spawnEntities(state);
      expect(result.enemies.length).toBe(MAX_ENEMIES);
    });

    it("does not spawn in WAITING phase", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.WAITING, scrollY: 5000, nextEnemySpawnDist: 100 };
      const result = spawnEntities(state);
      expect(result.enemies.length).toBe(0);
    });

    it("enemy Y is above screen (negative)", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, scrollY: 400, nextEnemySpawnDist: 300 };
      const result = spawnEntities(state);
      for (const e of result.enemies) {
        expect(e.y).toBeLessThan(0);
      }
    });
  });

  describe("createInitialState", () => {
    it("creates valid initial state", () => {
      const state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      expect(state.phase).toBe(PHASE.WAITING);
      expect(state.jet1Lives).toBe(INITIAL_LIVES);
      expect(state.jet2Lives).toBe(INITIAL_LIVES);
      expect(state.jet1Fuel).toBe(INITIAL_FUEL);
      expect(state.jet2Fuel).toBe(INITIAL_FUEL);
      expect(state.jet1Alive).toBe(true);
      expect(state.jet2Alive).toBe(true);
      expect(state.section).toBe(0);
      expect(state.score1).toBe(0);
      expect(state.score2).toBe(0);
      expect(state.enemies).toEqual([]);
      expect(state.fuels).toEqual([]);
      expect(state.bridgeActive).toBe(false);
    });

    it("has spawn thresholds", () => {
      const state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      expect(state.nextEnemySpawnDist).toBeGreaterThan(0);
      expect(state.nextFuelSpawnDist).toBeGreaterThan(0);
      expect(state.nextBridgeSpawnDist).toBeGreaterThan(0);
    });
  });

  describe("jet movement", () => {
    it("moves jet laterally within bounds", () => {
      const state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      const moved = moveJet(state, 1, 1); // right
      expect(moved.jet1X).toBeGreaterThan(state.jet1X);
    });

    it("clamps jet position to canvas bounds", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, jet1X: CANVAS_W - 1 };
      const moved = moveJet(state, 1, 1);
      expect(moved.jet1X).toBeLessThanOrEqual(CANVAS_W);
    });

    it("does not move dead jet", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, jet1Alive: false };
      const moved = moveJet(state, 1, 1);
      expect(moved.jet1X).toBe(state.jet1X);
    });
  });

  describe("missile firing", () => {
    it("fires missile from jet position", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING };
      const fired = fireMissile(state, 1);
      expect(fired.m1Active).toBe(true);
      expect(fired.m1X).toBe(state.jet1X);
    });

    it("does not fire when missile already active", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, m1Active: true };
      const fired = fireMissile(state, 1);
      expect(fired).toBe(state);
    });

    it("does not fire when jet is dead", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, jet1Alive: false };
      const fired = fireMissile(state, 1);
      expect(fired.m1Active).toBe(false);
    });
  });

  describe("mine deployment", () => {
    it("deploys mine at jet position", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING };
      const deployed = deployMine(state, 1);
      expect(deployed.mineCount).toBe(1);
      expect(deployed.mines[0].owner).toBe(1);
      expect(deployed.mines[0].active).toBe(true);
    });

    it("blocks mines in PACIFIST mode", () => {
      let state = createInitialState(GAME_MODE.PACIFIST, 42);
      state = { ...state, phase: PHASE.FLYING };
      const deployed = deployMine(state, 1);
      expect(deployed.mineCount).toBe(0);
    });

    it("respects mine cooldown", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, jet1MineCooldown: 100 };
      const deployed = deployMine(state, 1);
      expect(deployed.mineCount).toBe(0);
    });

    it("does not deploy when dead", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, jet1Alive: false };
      const deployed = deployMine(state, 1);
      expect(deployed.mineCount).toBe(0);
    });

    it("returns correct cooldowns per mode", () => {
      expect(getMineCooldown(GAME_MODE.RIVER_DUEL)).toBe(300);
      expect(getMineCooldown(GAME_MODE.BLITZ)).toBe(180);
      expect(getMineCooldown(GAME_MODE.PACIFIST)).toBe(Infinity);
    });
  });

  describe("missile collision with enemies (screen-space)", () => {
    it("destroys enemy and awards correct score", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        phase: PHASE.FLYING,
        m1Active: true,
        m1X: 100,
        m1Y: 200,
        enemies: [{ type: ENEMY_TYPE.BOAT, x: 100, y: 200, alive: true }],
        enemyCount: 1,
      };
      const result = checkMissileHits(state);
      expect(result.enemies[0].alive).toBe(false);
      expect(result.m1Active).toBe(false);
      expect(result.score1).toBe(SCORE_BOAT);
    });

    it("awards different scores per enemy type", () => {
      for (const [type, expectedScore] of [
        [ENEMY_TYPE.BOAT, SCORE_BOAT],
        [ENEMY_TYPE.HELI, SCORE_HELI],
        [ENEMY_TYPE.JET, SCORE_JET],
      ]) {
        let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
        state = {
          ...state,
          m1Active: true,
          m1X: 100,
          m1Y: 200,
          enemies: [{ type, x: 100, y: 200, alive: true }],
          enemyCount: 1,
        };
        const result = checkMissileHits(state);
        expect(result.score1).toBe(expectedScore);
      }
    });

    it("does not hit dead enemies", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        m1Active: true,
        m1X: 100,
        m1Y: 200,
        enemies: [{ type: ENEMY_TYPE.BOAT, x: 100, y: 200, alive: false }],
        enemyCount: 1,
      };
      const result = checkMissileHits(state);
      expect(result.m1Active).toBe(true);
    });
  });

  describe("bridge mechanics (screen-space)", () => {
    it("bridge hit decrements HP", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        m1Active: true,
        m1X: CANVAS_W / 2,
        m1Y: 200,
        bridgeY: 200,
        bridgeActive: true,
        bridgeHp: BRIDGE_HP,
      };
      const result = checkBridgeHits(state);
      expect(result.bridgeHp).toBe(BRIDGE_HP - 1);
      expect(result.m1Active).toBe(false);
    });

    it("bridge destroyed awards points and triggers event", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        m1Active: true,
        m1X: CANVAS_W / 2,
        m1Y: 200,
        bridgeY: 200,
        bridgeActive: true,
        bridgeHp: 1,
      };
      const result = checkBridgeHits(state);
      expect(result.bridgeActive).toBe(false);
      expect(result.bridgeHp).toBe(0);
      expect(result.score1).toBe(SCORE_BRIDGE);
      expect(result.events.bridgeDestroyed).toBe(1);
    });

    it("jet collides with intact bridge", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        jet1Y: 200,
        bridgeY: 200,
        bridgeActive: true,
        bridgeHp: 3,
      };
      const result = checkBridgeCollision(state);
      expect(result.events.death).toBe(1);
    });

    it("no collision with destroyed bridge", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        jet1Y: 200,
        bridgeY: 200,
        bridgeActive: false,
      };
      const result = checkBridgeCollision(state);
      expect(result).toBe(state);
    });
  });

  describe("fuel mechanics (screen-space)", () => {
    it("captures fuel station (first come first served)", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        fuels: [{ x: state.jet1X, y: state.jet1Y, available: true }],
        fuelCount: 1,
        jet1Fuel: 100,
      };
      const result = checkFuelCapture(state);
      expect(result.fuels[0].available).toBe(false);
      expect(result.jet1Fuel).toBeGreaterThan(100);
      expect(result.events.fuelCapture).toBe(1);
    });

    it("does not capture unavailable fuel", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        fuels: [{ x: state.jet1X, y: state.jet1Y, available: false }],
        fuelCount: 1,
        jet1Fuel: 100,
      };
      const result = checkFuelCapture(state);
      expect(result.jet1Fuel).toBe(100);
    });

    it("fuel drain depletes over time", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, jet1Fuel: 10 };

      for (let i = 0; i < 20; i++) {
        state = drainFuel(state, i);
      }
      expect(state.jet1Fuel).toBeLessThan(10);
    });

    it("fuel empty triggers death event", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, jet1Fuel: 1 };

      for (let i = 0; i < 20; i++) {
        state = drainFuel(state, i);
      }
      expect(state.jet1Fuel).toBe(0);
      expect(state.events.fuelEmpty).toBe(1);
    });
  });

  describe("updateEnemies (screen-space drift)", () => {
    it("drifts enemies downward by scrollDelta", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        scrollY: 500,
        enemies: [{ type: ENEMY_TYPE.BOAT, x: 320, y: 100, alive: true, vx: 0 }],
        enemyCount: 1,
      };
      const result = updateEnemies(state, 2);
      expect(result.enemies[0].y).toBe(102);
    });

    it("removes enemies that scroll off bottom", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        scrollY: 500,
        enemies: [{ type: ENEMY_TYPE.BOAT, x: 320, y: CANVAS_H + 60, alive: true, vx: 0 }],
        enemyCount: 1,
      };
      const result = updateEnemies(state, 2);
      expect(result.enemies.length).toBe(0);
    });

    it("enemy jets rush downward extra fast", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        scrollY: 500,
        enemies: [{ type: ENEMY_TYPE.JET, x: 320, y: 100, alive: true, vx: 0 }],
        enemyCount: 1,
      };
      const result = updateEnemies(state, 2);
      // scroll drift (2) + jet rush (3) = 5
      expect(result.enemies[0].y).toBe(105);
    });
  });

  describe("updateFuels", () => {
    it("drifts fuel stations downward", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        fuels: [{ x: 300, y: 100, available: true }],
        fuelCount: 1,
      };
      const result = updateFuels(state, 2);
      expect(result.fuels[0].y).toBe(102);
    });

    it("removes fuel that scrolls off bottom", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        fuels: [{ x: 300, y: CANVAS_H + 60, available: true }],
        fuelCount: 1,
      };
      const result = updateFuels(state, 2);
      expect(result.fuels.length).toBe(0);
    });
  });

  describe("updateBridge", () => {
    it("drifts bridge downward", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, bridgeY: 100, bridgeActive: true };
      const result = updateBridge(state, 2);
      expect(result.bridgeY).toBe(102);
    });

    it("deactivates bridge that scrolls off bottom", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, bridgeY: CANVAS_H + 49, bridgeActive: true };
      const result = updateBridge(state, 2);
      expect(result.bridgeActive).toBe(false);
    });
  });

  describe("mine collisions", () => {
    it("mine hits opponent", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        mines: [{ x: state.jet2X, y: state.jet2Y, owner: 1, active: true }],
        mineCount: 1,
      };
      const result = checkMineCollisions(state);
      expect(result.events.mineHit).toBe(2);
      expect(result.score1).toBe(SCORE_MINE_HIT);
    });

    it("mine does not hit own player", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        mines: [{ x: state.jet1X, y: state.jet1Y, owner: 1, active: true }],
        mineCount: 1,
      };
      const result = checkMineCollisions(state);
      expect(result.events.mineHit).toBe(0);
    });

    it("mine does not hit invulnerable player", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        jet2Invuln: true,
        mines: [{ x: state.jet2X, y: state.jet2Y, owner: 1, active: true }],
        mineCount: 1,
      };
      const result = checkMineCollisions(state);
      expect(result.events.mineHit).toBe(0);
    });
  });

  describe("river collision", () => {
    it("detects jet outside river bounds", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      // Place jet at x=0 which is definitely on the left bank
      state = { ...state, jet1X: 5, scrollY: 500 };
      expect(checkRiverCollision(state, 1)).toBe(true);
    });

    it("no collision when jet is inside river", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      // Center of screen is definitely in the river
      state = { ...state, jet1X: CANVAS_W / 2, scrollY: 500 };
      expect(checkRiverCollision(state, 1)).toBe(false);
    });

    it("no collision when invulnerable", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, jet1X: 5, jet1Invuln: true, scrollY: 500 };
      expect(checkRiverCollision(state, 1)).toBe(false);
    });
  });

  describe("death and respawn", () => {
    it("handleDeath decrements lives and marks dead", () => {
      const state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      const result = handleDeath(state, 1);
      expect(result.jet1Lives).toBe(INITIAL_LIVES - 1);
      expect(result.jet1Alive).toBe(false);
      expect(result.jet1Respawning).toBe(true);
    });

    it("processRespawns restores jet after timer", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = handleDeath(state, 1);
      state = { ...state, jet1RespawnTimer: 0 };

      const result = processRespawns(state);
      expect(result.jet1Alive).toBe(true);
      expect(result.jet1Respawning).toBe(false);
      expect(result.jet1Invuln).toBe(true);
    });
  });

  describe("game over", () => {
    it("detects game over when both players have 0 lives", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, jet1Lives: 0, jet1Alive: false, jet2Lives: 0, jet2Alive: false };
      expect(checkGameOver(state).ended).toBe(true);
    });

    it("game is over when one player exhausts all lives", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, jet1Lives: 0, jet1Alive: false, jet2Lives: 1, jet2Alive: true };
      const result = checkGameOver(state);
      expect(result.ended).toBe(true);
      expect(result.winner).toBe(2);
    });

    it("game is not over while both players have lives", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, jet1Lives: 1, jet1Alive: true, jet2Lives: 1, jet2Alive: true };
      expect(checkGameOver(state).ended).toBe(false);
    });

    it("getWinner returns player with higher score", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, score1: 1000, score2: 500 };
      expect(getWinner(state)).toBe(1);
      state = { ...state, score1: 500, score2: 1000 };
      expect(getWinner(state)).toBe(2);
    });

    it("getWinner handles tie (player 1 wins)", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, score1: 500, score2: 500 };
      expect(getWinner(state)).toBe(1);
    });
  });

  describe("timers", () => {
    it("tickTimers decrements invulnerability", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, jet1Invuln: true, jet1InvulnTimer: 2 };
      state = tickTimers(state);
      expect(state.jet1InvulnTimer).toBe(1);
      state = tickTimers(state);
      expect(state.jet1InvulnTimer).toBe(0);
      expect(state.jet1Invuln).toBe(false);
    });

    it("tickTimers decrements mine cooldown", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, jet1MineCooldown: 5 };
      state = tickTimers(state);
      expect(state.jet1MineCooldown).toBe(4);
    });

    it("clearEvents resets all event flags", () => {
      const state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state.events.death = 1;
      state.events.enemyKill = 2;
      state.events.fuelCapture = 1;
      const cleared = clearEvents(state);
      expect(cleared.events.death).toBe(0);
      expect(cleared.events.enemyKill).toBe(0);
      expect(cleared.events.fuelCapture).toBe(0);
    });
  });

  describe("scroll mechanics", () => {
    it("updateScroll increases scrollY", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, jet1Speed: 2, jet2Speed: 2 };
      const { state: newState, scrollDelta } = updateScroll(state);
      expect(newState.scrollY).toBeGreaterThan(0);
      expect(scrollDelta).toBeGreaterThan(0);
    });

    it("updateScroll updates section milestone", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, scrollY: 1999 };
      const { state: newState } = updateScroll(state);
      expect(newState.section).toBe(1); // (1999+2)/2000 = 1
    });
  });

  describe("purity of functions", () => {
    it("moveJet does not mutate input state", () => {
      const state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      const x = state.jet1X;
      moveJet(state, 1, 1);
      expect(state.jet1X).toBe(x);
    });

    it("fireMissile does not mutate input state", () => {
      const state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      const active = state.m1Active;
      fireMissile(state, 1);
      expect(state.m1Active).toBe(active);
    });

    it("handleDeath does not mutate input state", () => {
      const state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      const lives = state.jet1Lives;
      handleDeath(state, 1);
      expect(state.jet1Lives).toBe(lives);
    });
  });
});
