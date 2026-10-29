import { describe, it, expect } from "vitest";
import {
  checkRoundEnd,
  createInitialState,
  handleRespawns,
  stepTick,
  updateBailey,
} from "../../../../js/lib/games/hex_frost/physics.js";
import {
  BAILEY_STATE,
  ENEMY_TYPE,
  EVENT,
  GAME_MODE,
  PHASE,
} from "../../../../js/lib/games/hex_frost/protocol.js";

const STILL = { left: false, right: false, up: false, down: false };

// A building state whose row 0 has no block anywhere: whoever is on it is in the water.
function openWater() {
  const state = { ...createInitialState(0, 1), phase: PHASE.BUILDING };
  state.blockRows = state.blockRows.map((row, index) =>
    index === 0 ? { ...row, blocks: [] } : row,
  );
  return state;
}

describe("the end of a round", () => {
  it.each([1, 2])("goes to player %i once they are in their igloo", (winner) => {
    const state = { ...createInitialState(0, 1), phase: PHASE.BUILDING, roundWinner: winner };
    const ended = checkRoundEnd(state);
    expect(ended.phase).toBe(PHASE.ROUND_END);
    const key = winner === 1 ? "p1" : "p2";
    expect(ended[key]).not.toBe(state[key]);
  });

  it("is not over while nobody is home", () => {
    const state = { ...createInitialState(0, 1), phase: PHASE.BUILDING, roundWinner: 0 };
    expect(checkRoundEnd(state).phase).toBe(PHASE.BUILDING);
  });
});

describe("falling in the water", () => {
  it("costs a life and starts the respawn, after a missed landing", () => {
    const state = openWater();
    state.p1 = {
      ...state.p1,
      state: BAILEY_STATE.JUMPING,
      jumpFromRow: -1,
      jumpToRow: 0,
      jumpProgress: 0.99,
    };

    const fallen = updateBailey(state, "p1", STILL);

    expect(fallen.p1).toMatchObject({ state: BAILEY_STATE.FALLING, lives: 2 });
    expect(fallen.p1RespawnTimer).toBe(90);
    expect(fallen.events & EVENT.SPLASH).toBeTruthy();
  });

  it("costs a life and starts the respawn, after walking off a block", () => {
    const state = openWater();
    state.p2 = { ...state.p2, row: 0, state: BAILEY_STATE.IDLE };

    const fallen = updateBailey(state, "p2", { ...STILL, left: true, up: true });

    expect(fallen.p2).toMatchObject({ state: BAILEY_STATE.FALLING, lives: 2 });
    expect(fallen.p2RespawnTimer).toBe(90);
  });

  it("brings the player back on the shore once the respawn runs out", () => {
    const state = openWater();
    state.p1 = { ...state.p1, row: 0, x: 300, state: BAILEY_STATE.FALLING, lives: 2 };
    state.p1RespawnTimer = 1;

    const back = handleRespawns(state);

    expect(back.p1).toMatchObject({ state: BAILEY_STATE.IDLE, row: -1, x: 160 });
  });

  it("keeps a player with no lives left out of the round", () => {
    const state = openWater();
    state.p1 = { ...state.p1, row: 0, state: BAILEY_STATE.FALLING, lives: 0 };
    state.p1RespawnTimer = 1;

    const out = handleRespawns(state);

    expect(out.p1.state).toBe(BAILEY_STATE.DEAD);
    expect(out.p1RespawnTimer).toBe(0);
  });
});

describe("a round both players are out of", () => {
  it("goes to whoever built more of their igloo", () => {
    const state = { ...createInitialState(0, 1), phase: PHASE.BUILDING };
    state.p1 = { ...state.p1, lives: 0, iglooPieces: 4 };
    state.p2 = { ...state.p2, lives: 0, iglooPieces: 7 };

    const ended = checkRoundEnd(state);

    expect(ended).toMatchObject({ phase: PHASE.ROUND_END, roundWinner: 2 });
    expect(ended.p2.roundWins).toBe(1);
  });

  it("goes to nobody when they built the same", () => {
    const state = { ...createInitialState(0, 1), phase: PHASE.BUILDING };
    state.p1 = { ...state.p1, lives: 0, iglooPieces: 5 };
    state.p2 = { ...state.p2, lives: 0, iglooPieces: 5 };

    expect(checkRoundEnd(state)).toMatchObject({ phase: PHASE.ROUND_END, roundWinner: 0 });
  });
});

describe("the two sides of the ice", () => {
  const seeds = Array.from({ length: 40 }, (_, index) => index + 1);

  it("drift toward either player's side, drawn per round", () => {
    const tops = new Set();
    for (const seed of seeds) {
      const { blockRows } = createInitialState(GAME_MODE.ARCTIC_RACE, seed);
      tops.add(blockRows[0].direction);
      blockRows.slice(1).forEach((row, index) => {
        expect(row.direction).toBe(-blockRows[index].direction);
      });
    }
    expect(tops).toEqual(new Set([1, -1]));
  });

  it("send the bears toward either player, mirrored", () => {
    const sides = new Set();
    for (const seed of seeds) {
      const bears = createInitialState(GAME_MODE.BLIZZARD, seed).enemies.filter(
        (enemy) => enemy.type === ENEMY_TYPE.BEAR,
      );
      expect(bears).toHaveLength(2);
      const [middle, edge] = bears;
      expect(edge.state).toBe(-middle.state);
      // The second bear starts by the igloo it walks toward.
      if (edge.state === -1) expect(edge.x).toBeLessThan(160);
      else expect(edge.x).toBeGreaterThan(460);
      sides.add(middle.state);
    }
    expect(sides).toEqual(new Set([1, -1]));
  });
});

describe("one building frame", () => {
  const building = () => ({
    ...createInitialState(GAME_MODE.ARCTIC_RACE, 1),
    phase: PHASE.BUILDING,
    enemies: [],
  });

  it("drifts the ice and moves each bailey on its own inputs", () => {
    const state = building();

    const next = stepTick(state, { ...STILL, left: true }, { ...STILL, down: true });

    expect(next.blockRows[0].offset).not.toBe(state.blockRows[0].offset);
    expect(next.p1.x).toBeLessThan(state.p1.x);
    expect(next.p2.state).toBe(BAILEY_STATE.JUMPING);
    expect(next.events & EVENT.JUMP).toBeTruthy();
    expect(next.temperature).toBeLessThan(state.temperature);
  });

  it("starts from no events, whatever the last frame heard", () => {
    const next = stepTick({ ...building(), events: EVENT.SPLASH }, STILL, STILL);

    expect(next.events).toBe(0);
  });

  it("ends the round the frame a builder walks into a finished igloo", () => {
    const state = building();
    state.p2 = { ...state.p2, x: 575, iglooComplete: true };

    const next = stepTick(state, STILL, STILL);

    expect(next).toMatchObject({ phase: PHASE.ROUND_END, roundWinner: 2 });
    expect(next.p2.roundWins).toBe(1);
  });
});
