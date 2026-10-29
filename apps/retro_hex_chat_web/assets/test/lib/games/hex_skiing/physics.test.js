import { describe, it, expect } from "vitest";
import {
  createInitialState,
  packState,
  unpackState,
  updateSkier,
  updateScroll,
  updateItems,
  getScrollSpeed,
  generateChunk,
  ensureChunks,
  ensureGates,
  checkCollisions,
  checkGates,
  updateAvalanche,
  updateBlizzard,
  checkGameOver,
  startNextRound,
  determineWinner,
  stepTick,
  CANVAS_W,
  CANVAS_H,
  SCROLL_SPEED_BASE,
  LATERAL_MAX,
  SKIER_SCREEN_Y,
  SKIER_H,
  STUN_TREE,
  STUN_ROCK,
  BOOST_DURATION,
  ICE_DURATION,
  CHUNK_SIZE,
  GATE_INTERVAL,
  COURSE_LENGTH,
  ITEM_SPAWN_INTERVAL,
} from "../../../../js/lib/games/hex_skiing/physics.js";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { PHASE, GAME_MODE, SKIER_STATE } from "../../../../js/lib/games/hex_skiing/protocol.js";

/** A skier mid-slope with a clean run behind it, changed by `overrides`. */
function makeSkier(overrides = {}) {
  return {
    x: CANVAS_W / 2,
    velX: 0,
    state: SKIER_STATE.SKIING,
    timer: 0,
    boostTimer: 0,
    iceTimer: 0,
    stunTimer: 0,
    distance: 0,
    ...overrides,
  };
}

/** A round under way in `mode`, on seed 42. */
function racingState(mode = GAME_MODE.ALPINE_RACE) {
  return { ...createInitialState(mode, 42), phase: PHASE.RACING };
}

/** `thing` placed where skier one is now: on its line, at its height. */
function atSkierOne(state, thing) {
  return { x: state.p1.x, y: state.scrollY + SKIER_SCREEN_Y, ...thing };
}

/** A slalom gate `width` wide at skier one's height, its left post `dx` from the skier. */
function gateAtSkierOne(state, dx, width) {
  return atSkierOne(state, {
    x: state.p1.x + dx,
    width,
    clearedP1: false,
    clearedP2: false,
  });
}

describe("Hex Skiing Physics", () => {
  describe("createInitialState", () => {
    it("creates valid state for Alpine Race", () => {
      const state = createInitialState(GAME_MODE.ALPINE_RACE, 12345);
      expect(state.phase).toBe(PHASE.WAITING);
      expect(state.mode).toBe(GAME_MODE.ALPINE_RACE);
      expect(state.seed).toBe(12345);
      expect(state.scrollY).toBe(0);
      expect(state.p1.x).toBeLessThan(CANVAS_W / 2);
      expect(state.p2.x).toBeGreaterThan(CANVAS_W / 2);
      expect(state.p1.timer).toBe(0);
      expect(state.p2.timer).toBe(0);
      expect(state.avalancheSpeed).toBeGreaterThan(0);
    });

    it("creates valid state for Clean Run (no avalanche)", () => {
      const state = createInitialState(GAME_MODE.CLEAN_RUN, 99);
      expect(state.avalancheSpeed).toBe(0);
    });

    it("creates valid state for Avalanche Escape", () => {
      const state = createInitialState(GAME_MODE.AVALANCHE_ESCAPE, 77);
      expect(state.avalancheSpeed).toBeGreaterThan(0);
    });
  });

  describe("updateSkier", () => {
    it("moves left when left input is held", () => {
      const skier = makeSkier();
      const result = updateSkier(skier, { left: true, right: false });
      expect(result.velX).toBeLessThan(0);
      expect(result.x).toBeLessThan(skier.x);
    });

    it("moves right when right input is held", () => {
      const skier = makeSkier();
      const result = updateSkier(skier, { left: false, right: true });
      expect(result.velX).toBeGreaterThan(0);
      expect(result.x).toBeGreaterThan(skier.x);
    });

    it("applies friction when no input", () => {
      const skier = makeSkier({ velX: 3.0 });
      const result = updateSkier(skier, { left: false, right: false });
      expect(Math.abs(result.velX)).toBeLessThan(Math.abs(skier.velX));
    });

    it("clamps lateral speed to max", () => {
      const skier = makeSkier({ velX: LATERAL_MAX + 5 });
      const result = updateSkier(skier, { left: false, right: true });
      expect(result.velX).toBeLessThanOrEqual(LATERAL_MAX);
    });

    it("clamps position to canvas bounds", () => {
      const skier = makeSkier({ x: 1, velX: -5 });
      const result = updateSkier(skier, { left: true, right: false });
      expect(result.x).toBeGreaterThanOrEqual(4); // SKIER_W / 2
    });

    it("does not move when stunned", () => {
      const skier = makeSkier({ stunTimer: 10, state: SKIER_STATE.CRASHED });
      const result = updateSkier(skier, { left: true, right: false });
      expect(result.x).toBe(skier.x);
      expect(result.velX).toBe(0);
      expect(result.stunTimer).toBe(9);
    });

    it("recovers from stun when timer reaches 0", () => {
      const skier = makeSkier({ stunTimer: 1, state: SKIER_STATE.CRASHED });
      const result = updateSkier(skier, { left: false, right: false });
      expect(result.stunTimer).toBe(0);
      expect(result.state).toBe(SKIER_STATE.SKIING);
    });

    it("advances timer when moving", () => {
      const skier = makeSkier();
      const result = updateSkier(skier, { left: false, right: false });
      expect(result.timer).toBeGreaterThan(0);
    });

    it("keeps the timer running while stunned", () => {
      const skier = makeSkier({ stunTimer: 5, state: SKIER_STATE.CRASHED });
      const result = updateSkier(skier, { left: false, right: false });
      expect(result.timer).toBeCloseTo(1 / 60);
      expect(result.distance).toBe(skier.distance);
    });

    it("stops a skier's clock on the frame they cross the finish line", () => {
      /** The time on a skier's clock once past the line, stunned first for `stun` frames. */
      function finishTime(stun) {
        let skier = makeSkier({ distance: COURSE_LENGTH - 30, stunTimer: stun });
        while (skier.distance < COURSE_LENGTH) skier = updateSkier(skier, {});
        const atLine = skier.timer;
        for (let i = 0; i < 60; i++) skier = updateSkier(skier, {});
        expect(skier.timer).toBe(atLine);
        return atLine;
      }

      expect(finishTime(120) - finishTime(0)).toBeCloseTo(2);
    });

    it("decrements boost timer", () => {
      const skier = makeSkier({ boostTimer: 10, state: SKIER_STATE.BOOSTED });
      const result = updateSkier(skier, { left: false, right: false });
      expect(result.boostTimer).toBe(9);
    });

    it("reduces friction on ice", () => {
      const skierNormal = makeSkier({ velX: 3.0 });
      const skierIce = makeSkier({ velX: 3.0, iceTimer: 10 });
      const normalResult = updateSkier(skierNormal, {
        left: false,
        right: false,
      });
      const iceResult = updateSkier(skierIce, { left: false, right: false });
      // Ice friction is higher (less decel), so ice skier retains more speed
      expect(Math.abs(iceResult.velX)).toBeGreaterThan(Math.abs(normalResult.velX));
    });
  });

  describe("getScrollSpeed", () => {
    it("returns base speed when going straight", () => {
      const player = { velX: 0, stunTimer: 0, boostTimer: 0 };
      expect(getScrollSpeed(player)).toBe(SCROLL_SPEED_BASE);
    });

    it("returns 0 when stunned", () => {
      const player = { velX: 0, stunTimer: 5, boostTimer: 0 };
      expect(getScrollSpeed(player)).toBe(0);
    });

    it("returns boosted speed when boost active", () => {
      const player = { velX: 0, stunTimer: 0, boostTimer: 10 };
      expect(getScrollSpeed(player)).toBeGreaterThan(SCROLL_SPEED_BASE);
    });

    it("decreases with lateral movement", () => {
      const straight = { velX: 0, stunTimer: 0, boostTimer: 0 };
      const lateral = { velX: LATERAL_MAX, stunTimer: 0, boostTimer: 0 };
      expect(getScrollSpeed(lateral)).toBeLessThan(getScrollSpeed(straight));
    });
  });

  describe("generateChunk", () => {
    it("generates obstacles for a chunk", () => {
      const rng = createRng(42).next;
      const obstacles = generateChunk(rng, 0, {
        treeDensity: 4,
        rockDensity: 2,
        iceDensity: 1,
      });
      expect(obstacles.length).toBe(7); // 4 + 2 + 1
      expect(obstacles.filter((o) => o.type === "tree").length).toBe(4);
      expect(obstacles.filter((o) => o.type === "rock").length).toBe(2);
      expect(obstacles.filter((o) => o.type === "ice").length).toBe(1);
    });

    it("produces deterministic results for same seed", () => {
      const rng1 = createRng(42).next;
      const rng2 = createRng(42).next;
      const diff = { treeDensity: 3, rockDensity: 1, iceDensity: 0 };
      const obs1 = generateChunk(rng1, 0, diff);
      const obs2 = generateChunk(rng2, 0, diff);
      expect(obs1).toEqual(obs2);
    });
  });

  describe("ensureChunks", () => {
    it("generates chunks ahead of scroll", () => {
      const state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      const updated = ensureChunks(state);
      expect(updated.obstacles.length).toBeGreaterThan(0);
      expect(updated.nextChunkY).toBeGreaterThan(0);
    });

    it("culls old obstacles behind scroll", () => {
      let state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state = ensureChunks(state);
      state.scrollY = CHUNK_SIZE * 5; // Move far ahead
      state = ensureChunks(state);
      // All obstacles should be ahead of cull line
      const cullY = state.scrollY - CHUNK_SIZE;
      for (const obs of state.obstacles) {
        expect(obs.y).toBeGreaterThan(cullY);
      }
    });
  });

  describe("ensureGates", () => {
    it("generates a gate when scroll reaches gate interval", () => {
      let state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state.scrollY = GATE_INTERVAL - CANVAS_H + 1;
      state = ensureGates(state);
      expect(state.gates.length).toBe(1);
      expect(state.gates[0].clearedP1).toBe(false);
      expect(state.gates[0].clearedP2).toBe(false);
    });
  });

  describe("checkCollisions", () => {
    it("stuns player on tree collision", () => {
      let state = racingState();
      // Place a tree right at p1's position
      state.obstacles = [atSkierOne(state, { type: "tree", w: 10, h: 14 })];
      state = checkCollisions(state);
      expect(state.p1.stunTimer).toBe(STUN_TREE);
      expect(state.p1.state).toBe(SKIER_STATE.CRASHED);
    });

    it("stuns player on rock collision (shorter stun)", () => {
      let state = racingState();
      state.obstacles = [atSkierOne(state, { type: "rock", w: 8, h: 8 })];
      state = checkCollisions(state);
      expect(state.p1.stunTimer).toBe(STUN_ROCK);
    });

    it("applies ice effect on ice collision", () => {
      let state = racingState();
      state.obstacles = [atSkierOne(state, { type: "ice", w: 24, h: 16 })];
      state = checkCollisions(state);
      expect(state.p1.iceTimer).toBe(ICE_DURATION);
    });

    it("collects boost item", () => {
      let state = racingState();
      state.items = [atSkierOne(state, { type: 0, collected: 0 })];
      state = checkCollisions(state);
      expect(state.p1.boostTimer).toBe(BOOST_DURATION);
      expect(state.p1.state).toBe(SKIER_STATE.BOOSTED);
      expect(state.items[0].collected).toBe(1);
    });
  });

  describe("checkGates", () => {
    it("gives a skier past the finish line no gate bonus", () => {
      let state = racingState();
      state.p1 = { ...state.p1, distance: COURSE_LENGTH, timer: 70 };
      state.gates = [gateAtSkierOne(state, -20, 80)];
      state = checkGates(state);
      expect(state.gates[0].clearedP1).toBe(false);
      expect(state.p1.timer).toBe(70);
    });

    it("clears gate when skier passes through", () => {
      let state = racingState();
      state.gates = [gateAtSkierOne(state, -20, 80)];
      state = checkGates(state);
      expect(state.gates[0].clearedP1).toBe(true);
      expect(state.p1.timer).toBeLessThan(0 + 0.01); // Timer was 0, bonus -2 = max(0, -2) = 0
    });

    it("does not clear gate when skier is outside", () => {
      let state = racingState();
      state.gates = [gateAtSkierOne(state, 200, 40)];
      state = checkGates(state);
      expect(state.gates[0].clearedP1).toBe(false);
    });
  });

  describe("updateAvalanche", () => {
    it("advances avalanche position", () => {
      let state = racingState();
      const initialY = state.avalancheY;
      state = updateAvalanche(state);
      expect(state.avalancheY).toBeGreaterThan(initialY);
    });

    it("does nothing in clean run mode", () => {
      let state = racingState(GAME_MODE.CLEAN_RUN);
      const initialY = state.avalancheY;
      state = updateAvalanche(state);
      expect(state.avalancheY).toBe(initialY);
    });
  });

  describe("updateBlizzard", () => {
    it("triggers blizzard after cooldown expires", () => {
      let state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state.blizzardCooldown = 1;
      state = updateBlizzard(state);
      expect(state.blizzardActive).toBe(true);
    });

    it("ends blizzard after timer expires", () => {
      let state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state.blizzardActive = true;
      state.blizzardTimer = 1;
      state = updateBlizzard(state);
      expect(state.blizzardActive).toBe(false);
    });

    it("does nothing in clean run mode", () => {
      let state = createInitialState(GAME_MODE.CLEAN_RUN, 42);
      state.blizzardCooldown = 1;
      state = updateBlizzard(state);
      expect(state.blizzardActive).toBe(false);
    });
  });

  describe("packState / unpackState", () => {
    it("roundtrips state through pack/unpack", () => {
      const state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state.p1.x = 200;
      state.p2.x = 400;
      state.p1.timer = 15.5;
      state.gates = [{ x: 100, y: 600, width: 60, clearedP1: true, clearedP2: false }];

      const packed = packState(state);
      const unpacked = unpackState(packed);

      expect(unpacked.p1.x).toBe(200);
      expect(unpacked.p2.x).toBe(400);
      expect(unpacked.p1.timer).toBe(15.5);
      expect(unpacked.gates[0].clearedP1).toBe(true);
    });
  });

  describe("updateScroll", () => {
    it("advances scroll by faster skier's speed", () => {
      let state = racingState();
      const initial = state.scrollY;
      state = updateScroll(state);
      expect(state.scrollY).toBeGreaterThan(initial);
    });

    it("scroll stops when both skiers are stunned", () => {
      let state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state.p1 = { ...state.p1, stunTimer: 10 };
      state.p2 = { ...state.p2, stunTimer: 10 };
      const initial = state.scrollY;
      state = updateScroll(state);
      expect(state.scrollY).toBe(initial);
    });
  });

  describe("updateItems", () => {
    it("spawns an item when timer expires", () => {
      let state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state.itemSpawnTimer = 1;
      state = updateItems(state);
      expect(state.items.length).toBe(1);
      expect(state.itemSpawnTimer).toBe(ITEM_SPAWN_INTERVAL);
    });

    it("does not spawn items in clean run mode", () => {
      let state = createInitialState(GAME_MODE.CLEAN_RUN, 42);
      state.itemSpawnTimer = 1;
      state = updateItems(state);
      expect(state.items.length).toBe(0);
    });

    it("culls items that scroll off screen", () => {
      let state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state.items = [{ type: 0, x: 300, y: -5000, collected: 0 }];
      state.scrollY = 3000;
      state = updateItems(state);
      expect(state.items.length).toBe(0);
    });
  });

  describe("checkGameOver", () => {
    /** A round in `mode` checked once the avalanche has run past the skiers. */
    function afterAvalanche(mode) {
      const state = racingState(mode);
      state.avalancheY = state.scrollY + SKIER_SCREEN_Y + SKIER_H + 10;
      return checkGameOver(state);
    }

    it("ends round when both players finish the course", () => {
      let state = racingState();
      state.p1 = { ...state.p1, distance: COURSE_LENGTH + 1 };
      state.p2 = { ...state.p2, distance: COURSE_LENGTH + 1 };
      state = checkGameOver(state);
      expect(state.phase === PHASE.ROUND_END || state.phase === PHASE.FINISHED).toBe(true);
    });

    it("gives the round to the finisher over a skier still on the course", () => {
      let state = racingState();
      state.p1 = { ...state.p1, distance: COURSE_LENGTH + CANVAS_H * 2, timer: 80 };
      state.p2 = { ...state.p2, distance: COURSE_LENGTH - 500, timer: 60 };
      state = checkGameOver(state);
      expect(state.phase).toBe(PHASE.ROUND_END);
      expect(state.p1RoundWins).toBe(1);
      expect(state.p2RoundWins).toBe(0);
    });

    it("never lets the avalanche catch a skier who has finished", () => {
      const state = racingState();
      state.p1 = { ...state.p1, distance: COURSE_LENGTH + 10, stunTimer: 30 };
      state.p2 = { ...state.p2, distance: COURSE_LENGTH - 500 };
      state.avalancheY = state.scrollY + SKIER_SCREEN_Y + SKIER_H + 10;
      const over = checkGameOver(state);

      expect(over.phase).toBe(PHASE.ROUND_END);
      expect(over.p1RoundWins).toBe(1);
      expect(over.p2RoundWins).toBe(0);
    });

    it("keeps the round going while only the finisher sits under the avalanche", () => {
      const state = racingState();
      state.p1 = { ...state.p1, distance: COURSE_LENGTH + 10, stunTimer: 30 };
      state.p2 = { ...state.p2, distance: COURSE_LENGTH - 500 };
      state.avalancheY = state.scrollY + SKIER_SCREEN_Y;

      expect(checkGameOver(state).phase).toBe(PHASE.RACING);
    });

    it("ends round when avalanche engulfs (past skier screen Y)", () => {
      const state = afterAvalanche(GAME_MODE.ALPINE_RACE);
      expect(state.phase === PHASE.ROUND_END || state.phase === PHASE.FINISHED).toBe(true);
    });

    it("escape mode ends when both are engulfed", () => {
      expect(afterAvalanche(GAME_MODE.AVALANCHE_ESCAPE).phase).toBe(PHASE.FINISHED);
    });

    it("does not end round in clean run when no avalanche", () => {
      let state = racingState(GAME_MODE.CLEAN_RUN);
      state.p1 = { ...state.p1, distance: 100 };
      state.p2 = { ...state.p2, distance: 100 };
      state = checkGameOver(state);
      expect(state.phase).toBe(PHASE.RACING);
    });
  });

  describe("stepTick", () => {
    function racing() {
      return { ...racingState(), obstacles: [], gates: [], nextChunkY: 10_000 };
    }

    it("moves both skiers on their own inputs and scrolls the slope", () => {
      const state = racing();
      const next = stepTick(state, {
        p1: { left: true, right: false },
        p2: { left: false, right: true },
      });

      expect(next.p1.x).toBeLessThan(state.p1.x);
      expect(next.p2.x).toBeGreaterThan(state.p2.x);
      expect(next.scrollY).toBeGreaterThan(state.scrollY);
      expect(next.p1.timer).toBeCloseTo(1 / 60);
    });

    it("leaves the state it was given untouched", () => {
      const state = racing();
      const p1 = state.p1;
      stepTick(state, { p1: { left: true, right: false }, p2: { left: false, right: false } });

      expect(state.p1).toBe(p1);
      expect(state.scrollY).toBe(0);
    });

    it("settles a crash and the round's end within the tick", () => {
      const crash = racing();
      crash.obstacles = [
        { type: "tree", x: crash.p2.x, y: SKIER_SCREEN_Y + SCROLL_SPEED_BASE, w: 10, h: 14 },
      ];
      expect(stepTick(crash, { p1: {}, p2: {} }).p2.stunTimer).toBe(STUN_TREE);

      const done = racing();
      done.p1 = { ...done.p1, distance: COURSE_LENGTH };
      done.p2 = { ...done.p2, distance: COURSE_LENGTH };
      expect(stepTick(done, { p1: {}, p2: {} }).phase).toBe(PHASE.ROUND_END);
    });
  });

  describe("startNextRound", () => {
    it("advances to next round", () => {
      let state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state.round = 0;
      state.p1RoundWins = 1;
      state.scrollY = 5000;
      state = startNextRound(state);
      expect(state.round).toBe(1);
      expect(state.scrollY).toBe(0);
      expect(state.p1.x).toBeLessThan(CANVAS_W / 2);
      expect(state.phase).toBe(PHASE.COUNTDOWN);
      expect(state.p1RoundWins).toBe(1); // Preserved
    });

    it("preserves avalancheSpeed=0 for clean run mode", () => {
      let state = createInitialState(GAME_MODE.CLEAN_RUN, 42);
      state.round = 0;
      state = startNextRound(state);
      expect(state.avalancheSpeed).toBe(0);
    });

    it("increases difficulty for next round", () => {
      let state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state.round = 0;
      const gateWidth0 = state.gateWidth;
      state = startNextRound(state);
      expect(state.gateWidth).toBeLessThan(gateWidth0);
    });
  });

  describe("updateSkier edge cases", () => {
    it("clamps to right canvas boundary", () => {
      const skier = makeSkier({ x: CANVAS_W - 1, velX: 5 });
      const result = updateSkier(skier, { left: false, right: true });
      expect(result.x).toBeLessThanOrEqual(CANVAS_W - 4); // SKIER_W / 2
    });

    it("cancels movement when both keys pressed", () => {
      const skier = makeSkier({ velX: 0 });
      const result = updateSkier(skier, { left: true, right: true });
      // No acceleration applied, only friction on 0 velocity
      expect(result.velX).toBe(0);
    });

    it("transitions from BOOSTED to SKIING when boost expires", () => {
      const skier = makeSkier({ boostTimer: 1, state: SKIER_STATE.BOOSTED });
      const result = updateSkier(skier, { left: false, right: false });
      expect(result.boostTimer).toBe(0);
      expect(result.state).toBe(SKIER_STATE.SKIING);
    });
  });

  describe("checkCollisions edge cases", () => {
    it("leaves a skier past the finish line standing", () => {
      const state = racingState();
      state.p1 = { ...state.p1, distance: COURSE_LENGTH };
      state.obstacles = [atSkierOne(state, { type: "tree", w: 10, h: 14 })];

      expect(checkCollisions(state).p1.stunTimer).toBe(0);
    });

    it("skips stunned players", () => {
      let state = racingState();
      state.p1 = { ...state.p1, stunTimer: 10, state: SKIER_STATE.CRASHED };
      state.obstacles = [atSkierOne(state, { type: "tree", w: 10, h: 14 })];
      state = checkCollisions(state);
      // Stun timer should not be reset (still 10, not STUN_TREE)
      expect(state.p1.stunTimer).toBe(10);
    });

    it("does not re-apply ice when already on ice", () => {
      let state = racingState();
      state.p1 = { ...state.p1, iceTimer: 50 };
      state.obstacles = [atSkierOne(state, { type: "ice", w: 24, h: 16 })];
      state = checkCollisions(state);
      expect(state.p1.iceTimer).toBe(50); // Not reset to ICE_DURATION
    });
  });

  describe("ensureGates edge cases", () => {
    it("generates multiple gates on large scroll jump", () => {
      let state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      // Jump scrollY far enough that multiple gates fit in the viewport
      // nextGateY starts at GATE_INTERVAL (600), lookAhead = scrollY + CANVAS_H
      // With scrollY = 0, nextGateY = 600, lookAhead = 480 → no gate yet
      // With scrollY = 200, lookAhead = 680 → gate at 600, next at 1200
      // Use scroll that puts us past multiple gate intervals from initial nextGateY
      state.scrollY = GATE_INTERVAL + CANVAS_H; // lookAhead = 600 + 480 + 480 = 1560
      state.nextGateY = GATE_INTERVAL; // starts at 600
      state = ensureGates(state);
      // Should generate gates at 600, 1200 (both <= lookAhead 1560)
      // Cull removes below scrollY - CHUNK_SIZE = 1080 - 600 = 480
      // Gate at 600 survives (600 > 480), gate at 1200 survives
      expect(state.gates.length).toBeGreaterThanOrEqual(2);
    });
  });

  describe("packState / unpackState roundtrip", () => {
    it("roundtrips gate y positions", () => {
      const state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state.gates = [
        { x: 100, y: 600, width: 80, clearedP1: false, clearedP2: false },
        { x: 200, y: 1200, width: 60, clearedP1: true, clearedP2: false },
      ];
      const packed = packState(state);
      const unpacked = unpackState(packed);
      expect(unpacked.gates[0].y).toBe(600);
      expect(unpacked.gates[1].y).toBe(1200);
    });

    it("roundtrips items with collected status", () => {
      const state = createInitialState(GAME_MODE.ALPINE_RACE, 42);
      state.items = [{ type: 0, x: 300, y: 5000, collected: 1 }];
      const packed = packState(state);
      const unpacked = unpackState(packed);
      expect(unpacked.items[0].collected).toBe(1);
      expect(unpacked.items[0].y).toBe(5000);
    });
  });

  describe("determineWinner", () => {
    it("returns 1 when p1 has more wins", () => {
      const state = { p1RoundWins: 2, p2RoundWins: 1 };
      expect(determineWinner(state)).toBe(1);
    });

    it("returns 2 when p2 has more wins", () => {
      const state = { p1RoundWins: 0, p2RoundWins: 2 };
      expect(determineWinner(state)).toBe(2);
    });

    it("returns 0 on draw", () => {
      const state = { p1RoundWins: 1, p2RoundWins: 1 };
      expect(determineWinner(state)).toBe(0);
    });
  });
});
