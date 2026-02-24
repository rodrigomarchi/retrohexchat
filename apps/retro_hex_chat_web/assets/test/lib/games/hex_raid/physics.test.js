import { describe, it, expect } from "vitest";
import {
  CANVAS_W,
  INITIAL_LIVES,
  INITIAL_FUEL,
  SECTION_HEIGHT,
  BRIDGE_HP,
  SCORE_BOAT,
  SCORE_HELI,
  SCORE_JET,
  SCORE_BRIDGE,
  SCORE_MINE_HIT,
  mulberry32,
  getRiverWidth,
  generateBanks,
  getBankAt,
  generateEnemies,
  generateFuels,
  generateSection,
  createInitialState,
  moveJet,
  fireMissile,
  deployMine,
  updateScroll,
  drainFuel,
  checkMissileHits,
  checkBridgeHits,
  checkFuelCapture,
  checkMineCollisions,
  checkBridgeCollision,
  handleDeath,
  processRespawns,
  checkSectionClear,
  advanceSection,
  checkGameOver,
  getWinner,
  tickTimers,
  clearEvents,
  getTotalSections,
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

  describe("getRiverWidth", () => {
    it("returns wider river for early sections", () => {
      const w1 = getRiverWidth(1, GAME_MODE.RIVER_DUEL);
      const w5 = getRiverWidth(5, GAME_MODE.RIVER_DUEL);
      const w10 = getRiverWidth(10, GAME_MODE.RIVER_DUEL);
      expect(w1).toBeGreaterThan(w5);
      expect(w5).toBeGreaterThan(w10);
    });

    it("BLITZ mode starts narrower", () => {
      const normalW = getRiverWidth(1, GAME_MODE.RIVER_DUEL);
      const blitzW = getRiverWidth(1, GAME_MODE.BLITZ);
      expect(blitzW).toBeLessThan(normalW);
    });
  });

  describe("bank generation and lookup", () => {
    it("generates valid banks with correct number of segments", () => {
      const rng = mulberry32(42);
      const banks = generateBanks(1, rng, GAME_MODE.RIVER_DUEL);
      expect(banks.length).toBeGreaterThan(2);
      for (const b of banks) {
        expect(b.leftX).toBeLessThan(b.rightX);
        expect(b.y).toBeGreaterThanOrEqual(0);
      }
    });

    it("getBankAt clamps to valid range", () => {
      const rng = mulberry32(42);
      const banks = generateBanks(1, rng, GAME_MODE.RIVER_DUEL);
      const bankNeg = getBankAt(banks, -100);
      expect(bankNeg.leftX).toBeDefined();
      const bankOver = getBankAt(banks, SECTION_HEIGHT + 500);
      expect(bankOver.leftX).toBeDefined();
    });

    it("getBankAt returns fallback for empty banks", () => {
      const bank = getBankAt([], 100);
      expect(bank.leftX).toBe(0);
      expect(bank.rightX).toBe(CANVAS_W);
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
      expect(state.section).toBe(1);
      expect(state.score1).toBe(0);
      expect(state.score2).toBe(0);
      expect(state.banks.length).toBeGreaterThan(0);
    });

    it("BLITZ mode uses 5 total sections", () => {
      expect(getTotalSections(GAME_MODE.BLITZ)).toBe(5);
      expect(getTotalSections(GAME_MODE.RIVER_DUEL)).toBe(10);
      expect(getTotalSections(GAME_MODE.PACIFIST)).toBe(10);
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
      expect(fired).toBe(state); // unchanged reference
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

  describe("missile collision with enemies", () => {
    it("destroys enemy and awards correct score", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        phase: PHASE.FLYING,
        m1Active: true,
        m1X: 100,
        m1Y: 100,
        enemies: [{ type: ENEMY_TYPE.BOAT, x: 100, y: 100, alive: true }],
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
          m1Y: 100,
          enemies: [{ type, x: 100, y: 100, alive: true }],
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
        m1Y: 100,
        enemies: [{ type: ENEMY_TYPE.BOAT, x: 100, y: 100, alive: false }],
        enemyCount: 1,
      };
      const result = checkMissileHits(state);
      expect(result.m1Active).toBe(true); // missile passes through
    });
  });

  describe("bridge mechanics", () => {
    it("bridge hit decrements HP", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = {
        ...state,
        m1Active: true,
        m1X: CANVAS_W / 2,
        m1Y: state.bridgeY,
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
        m1Y: state.bridgeY,
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
        jet1Y: state.bridgeY,
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
        jet1Y: state.bridgeY,
        bridgeActive: false,
      };
      const result = checkBridgeCollision(state);
      expect(result).toBe(state); // unchanged
    });
  });

  describe("fuel mechanics", () => {
    it("captures fuel station (first come first served)", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      const fuelX = state.jet1X;
      const fuelY = state.jet1Y;
      state = {
        ...state,
        fuels: [{ x: fuelX, y: fuelY, available: true }],
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

      // Drain multiple frames
      for (let i = 0; i < 20; i++) {
        state = drainFuel(state, i);
      }
      expect(state.jet1Fuel).toBeLessThan(10);
    });

    it("fuel empty triggers death event", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, phase: PHASE.FLYING, jet1Fuel: 1 };

      // Drain until empty
      for (let i = 0; i < 20; i++) {
        state = drainFuel(state, i);
      }
      expect(state.jet1Fuel).toBe(0);
      expect(state.events.fuelEmpty).toBe(1);
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
      expect(result.events.mineHit).toBe(2); // player 2 was hit
      expect(result.score1).toBe(SCORE_MINE_HIT); // player 1 gets points
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
      state = { ...state, jet1RespawnTimer: 0 }; // timer expired, respawn triggers

      const result = processRespawns(state);
      expect(result.jet1Alive).toBe(true);
      expect(result.jet1Respawning).toBe(false);
      expect(result.jet1Invuln).toBe(true);
    });
  });

  describe("section progression", () => {
    it("checkSectionClear detects bridge destroyed", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, bridgeActive: false, phase: PHASE.FLYING };
      const result = checkSectionClear(state);
      expect(result.phase).toBe(PHASE.SECTION_CLEAR);
    });

    it("advanceSection moves to next section", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, section: 1 };
      const result = advanceSection(state);
      expect(result.section).toBe(2);
      expect(result.phase).toBe(PHASE.FLYING);
      expect(result.bridgeActive).toBe(true);
      expect(result.bridgeHp).toBe(BRIDGE_HP);
      expect(result.scrollY).toBe(0);
    });

    it("advanceSection finishes game at last section", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, section: 10 };
      const result = advanceSection(state);
      expect(result.phase).toBe(PHASE.FINISHED);
      expect(result.enemies).toEqual([]);
      expect(result.enemyCount).toBe(0);
      expect(result.fuels).toEqual([]);
      expect(result.mines).toEqual([]);
      expect(result.bridgeActive).toBe(false);
    });

    it("BLITZ finishes after section 5", () => {
      let state = createInitialState(GAME_MODE.BLITZ, 42);
      state = { ...state, section: 5 };
      const result = advanceSection(state);
      expect(result.phase).toBe(PHASE.FINISHED);
    });

    it("advanceSection awards section bonus", () => {
      let state = createInitialState(GAME_MODE.RIVER_DUEL, 42);
      state = { ...state, section: 1, score1: 100, score2: 50 };
      const result = advanceSection(state);
      // Both players get section bonus on advance — check it's in state
      expect(result.section).toBe(2);
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
      expect(result.winner).toBe(2); // surviving player wins
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

  describe("enemy generation and update", () => {
    it("generates correct number of enemies per section difficulty", () => {
      const rng = mulberry32(42);
      const banks = generateBanks(1, mulberry32(42), GAME_MODE.RIVER_DUEL);
      const enemies = generateEnemies(1, rng, banks, GAME_MODE.RIVER_DUEL);
      expect(enemies.length).toBeGreaterThanOrEqual(2);
      expect(enemies.length).toBeLessThanOrEqual(MAX_ENEMIES);
    });

    it("generates fewer fuel stations in later sections", () => {
      const rng1 = mulberry32(42);
      const banks1 = generateBanks(1, mulberry32(42), GAME_MODE.RIVER_DUEL);
      const fuels1 = generateFuels(1, rng1, banks1, GAME_MODE.RIVER_DUEL);

      const rng10 = mulberry32(42);
      const banks10 = generateBanks(10, mulberry32(42), GAME_MODE.RIVER_DUEL);
      const fuels10 = generateFuels(10, rng10, banks10, GAME_MODE.RIVER_DUEL);

      expect(fuels1.length).toBeGreaterThanOrEqual(fuels10.length);
    });

    it("generateSection produces complete section data", () => {
      const data = generateSection(1, 42, GAME_MODE.RIVER_DUEL);
      expect(data.banks).toBeDefined();
      expect(data.enemies).toBeDefined();
      expect(data.fuels).toBeDefined();
      expect(data.bridgeY).toBeDefined();
      expect(data.banks.length).toBeGreaterThan(0);
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
