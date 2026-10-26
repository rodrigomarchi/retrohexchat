import { describe, expect, it } from "vitest";
import {
  EDGE_MAX,
  EDGE_MIN,
  GROUND_Y,
  PHASE,
  SCREENS,
  SEED,
  START_X,
  UNDER_Y,
} from "../../../../js/lib/games/hex_jungle/protocol.js";
import { stepLeft, stepRight } from "../../../../js/lib/games/hex_jungle/world.js";
import {
  changeScreen,
  createInitialState,
  shiftingInset,
  stepPlayer,
  logsFor,
  stepTick,
} from "../../../../js/lib/games/hex_jungle/physics.js";

const NONE = { left: false, right: false, up: false, down: false, jump: false };
const held = (keys) => ({ ...NONE, ...keys });

/** Run the player for `ticks` with the same keys held throughout. */
function run(state, keys, ticks) {
  let current = state;
  for (let i = 0; i < ticks; i++) current = stepPlayer(current, held(keys));
  return current;
}

/** A screen with one hole, at x 72–79: firm ground everywhere else. */
const LADDER_SCREEN = 0b00000001;

const onScreen = (player = {}, screen = LADDER_SCREEN) => {
  const state = createInitialState();
  return { ...state, screen, player: { ...state.player, ...player } };
};

describe("the expedition's start", () => {
  it("starts with 2000 points, three lives, twenty minutes and a stopped clock", () => {
    const state = createInitialState();
    expect(state.score).toBe(2000);
    expect(state.lives).toBe(3);
    expect(state.timerTicks).toBe(20 * 60 * 60);
    expect(state.clockRunning).toBe(false);
    expect(state.screen).toBe(SEED);
    expect(state.underground).toBe(false);
    expect(state.player).toMatchObject({ x: START_X, y: GROUND_Y });
  });
});

describe("running", () => {
  it("covers 30 pixels a second, and the first step starts the clock", () => {
    const state = onScreen();
    expect(run(state, {}, 60).clockRunning).toBe(false);

    const ran = run(state, { right: true }, 60);
    expect(ran.player.x).toBe(START_X + 30);
    expect(ran.player.facing).toBe(1);
    expect(ran.clockRunning).toBe(true);

    expect(run(state, { left: true }, 20).player).toMatchObject({ x: START_X - 10, facing: -1 });
  });
});

describe("jumping", () => {
  it("leaves the ground on a fresh press, and is back on it 33 ticks later", () => {
    const state = onScreen();
    const air = stepPlayer(state, held({ jump: true }));
    expect(air.player.y).toBeLessThan(GROUND_Y);
    expect(air.clockRunning).toBe(true);

    const peak = Math.min(
      ...[...Array(34).keys()].map((t) => run(air, { jump: true }, t).player.y),
    );
    expect(GROUND_Y - peak).toBe(11);
    expect(run(air, {}, 32).player.y).toBe(GROUND_Y);
    expect(run(air, {}, 32).player.jumpTick).toBeNull();
  });

  it("does not jump again while the key stays down after landing", () => {
    const landed = run(onScreen(), { jump: true }, 40);
    expect(landed.player.y).toBe(GROUND_Y);
    expect(run(landed, { jump: true }, 10).player.y).toBe(GROUND_Y);

    const released = stepPlayer(landed, held({}));
    expect(stepPlayer(released, held({ jump: true })).player.y).toBeLessThan(GROUND_Y);
  });

  it("keeps the direction it set out in, whatever is held in the air", () => {
    const state = onScreen({ x: 100 });
    let jumped = stepPlayer(state, held({ jump: true, right: true }));
    jumped = stepPlayer(jumped, held({ right: true }));
    const turned = run(jumped, { left: true }, 31);
    expect(turned.player.x).toBe(100 + 16);
    expect(turned.player.y).toBe(GROUND_Y);
  });

  it("can set its direction in the jump's first two ticks", () => {
    const state = onScreen({ x: 100 });
    const late = run(stepPlayer(state, held({ jump: true })), { right: true }, 32);
    expect(late.player.x).toBe(100 + 16);

    const still = run(stepPlayer(state, held({ jump: true })), {}, 2);
    expect(run(still, { left: true }, 30).player.x).toBe(100);
  });
});

describe("the edges of a screen", () => {
  it("walking off the right edge enters the next screen on its left", () => {
    const state = onScreen({ x: EDGE_MAX });
    const next = run(state, { right: true }, 2);
    expect(next.screen).toBe(stepRight(state.screen));
    expect(next.player.x).toBe(EDGE_MIN);
  });

  it("walking off the left edge enters the screen before on its right", () => {
    const state = onScreen({ x: EDGE_MIN });
    const previous = run(state, { left: true }, 2);
    expect(previous.screen).toBe(stepLeft(state.screen));
    expect(previous.player.x).toBe(EDGE_MAX);
  });

  it("255 screens to the right is back at the start", () => {
    let state = createInitialState();
    for (let i = 0; i < SCREENS; i++) state = changeScreen(state, 1);
    expect(state.screen).toBe(SEED);
  });
});

// ── The ground's hazards ──

/** A screen's byte from its scene (bits 3–5) and object (bits 0–2). */
const screenOf = (scene, object) => (scene << 3) | object;
const FIRE = 6;

/** A state in play on `screen`, with the player and anything else given. */
function playing(screen, player = {}, rest = {}) {
  const state = createInitialState();
  return {
    ...state,
    ...rest,
    screen,
    logs: rest.logs ?? logsFor(screen),
    phase: PHASE.PLAYING,
    clockRunning: true,
    player: { ...state.player, x: START_X, y: GROUND_Y, ...player },
  };
}

/** Tick with these keys held, and report every state on the way. */
function ticks(state, keys, count) {
  const seen = [state];
  for (let i = 0; i < count; i++) seen.push(stepTick(seen.at(-1), held(keys)));
  return seen;
}
const after = (state, keys, count) => ticks(state, keys, count).at(-1);

describe("a hole", () => {
  it("drops the player into the tunnel for 100 points, and costs no life", () => {
    const start = playing(screenOf(0, FIRE), { x: 70 });
    const below = after(after(start, { right: true }, 4), {}, 80);
    expect(below.underground).toBe(true);
    expect(below.player.y).toBe(UNDER_Y);
    expect(below.score).toBe(1900);
    expect(below.lives).toBe(3);
    expect(below.phase).toBe(PHASE.PLAYING);
  });

  it("never takes the score below nothing", () => {
    const start = playing(screenOf(0, FIRE), { x: 70 }, { score: 50 });
    expect(after(after(start, { right: true }, 4), {}, 80).score).toBe(0);
  });
});

describe("a pit", () => {
  it("is death once the player sinks past line 54", () => {
    const seen = ticks(playing(screenOf(2, FIRE), { x: 40 }), { right: true }, 60);
    const died = seen.findIndex((s) => s.phase === PHASE.DYING);
    expect(died).toBeGreaterThan(0);
    expect(seen[died - 1].player.y).toBeLessThanOrEqual(54);
    expect(seen[died].player.y).toBeGreaterThan(54);
  });

  it("is too wide to jump across: that takes the vine", () => {
    const start = playing(screenOf(2, FIRE), { x: 28 });
    const across = after(after(start, { right: true, jump: true }, 1), { right: true }, 60);
    expect(across.phase).toBe(PHASE.DYING);
  });
});

describe("a shifting pit", () => {
  it("narrows every 4 ticks, stays shut, then opens the same way back", () => {
    expect([0, 4, 8, 12, 16].map(shiftingInset)).toEqual([0, 4, 8, 16, 28]);
    expect([20, 100, 171].map(shiftingInset)).toEqual([null, null, null]);
    expect([172, 176, 180, 184, 188].map(shiftingInset)).toEqual([28, 16, 8, 4, 0]);
    expect([192, 255, 256].map(shiftingInset)).toEqual([0, 0, 0]);
  });

  it("holds the player while shut and swallows them while open", () => {
    const shifting = screenOf(6, FIRE);
    expect(after(playing(shifting, { x: 76 }, { tick: 100 }), {}, 30).phase).toBe(PHASE.PLAYING);
    expect(after(playing(shifting, { x: 76 }, { tick: 200 }), {}, 40).phase).toBe(PHASE.DYING);
  });
});

describe("crocodiles", () => {
  const swamp = screenOf(4, 0);

  it("are safe to stand on with their jaws shut, and only on their heads", () => {
    expect(after(playing(swamp, { x: 58 }, { tick: 10 }), {}, 30).phase).toBe(PHASE.PLAYING);
    expect(after(playing(swamp, { x: 66 }, { tick: 10 }), {}, 30).phase).toBe(PHASE.DYING);
  });

  it("leave only their eyes to stand on with their jaws open", () => {
    expect(after(playing(swamp, { x: 58 }, { tick: 130 }), {}, 30).phase).toBe(PHASE.DYING);
    expect(after(playing(swamp, { x: 62 }, { tick: 130 }), {}, 30).phase).toBe(PHASE.PLAYING);
  });
});

describe("logs", () => {
  it("roll left a pixel every second tick, and come back round from the right", () => {
    const rolling = playing(screenOf(0, 0), { x: 20 }, { logs: [{ x: 0 }] });
    expect(after(rolling, {}, 1).logs).toEqual([{ x: 159 }]);
    expect(after(playing(screenOf(0, 0), { x: 20 }, { logs: [{ x: 124 }] }), {}, 20).logs).toEqual([
      { x: 114 },
    ]);
  });

  it("start at x 124 on every screen entered", () => {
    // Byte 0 is not in the ring (it steps to itself); 64 is the same scene.
    const start = playing(screenOf(0, 0) | 0b01000000, { x: EDGE_MAX }, { logs: [{ x: 50 }] });
    const entered = after(start, { right: true }, 1);
    expect(entered.screen).not.toBe(start.screen);
    // They roll on the tick they appear, so a pixel short of where they start.
    const fresh = logsFor(entered.screen);
    expect(entered.logs).toHaveLength(fresh.length);
    entered.logs.forEach((log, i) => expect(fresh[i].x - log.x).toBeLessThanOrEqual(1));
  });

  it("a rolling one costs a point a tick of contact and stops the player, but never kills", () => {
    const start = playing(screenOf(0, 0), { x: 100 }, { logs: [{ x: 102 }] });
    const seen = ticks(start, { right: true }, 6);
    expect(seen.at(-1).score).toBe(2000 - 6);
    expect(seen.slice(2).every((s) => s.player.x === seen[1].player.x)).toBe(true);
    expect(seen.every((s) => s.phase === PHASE.PLAYING)).toBe(true);
  });

  it("a still one costs a point a tick of contact, and the player keeps going", () => {
    const start = playing(screenOf(0, 4), { x: 118 });
    const seen = ticks(start, { right: true }, 10);
    expect(seen.at(-1).score).toBeLessThan(2000);
    expect(seen.at(-1).player.x).toBe(123);
  });

  it("are jumped clear", () => {
    const start = playing(screenOf(0, 4), { x: 118 });
    const over = after(after(start, { right: true, jump: true }, 1), { right: true }, 34);
    expect(over.player.x).toBeGreaterThan(124 + 8);
    expect(over.score).toBe(2000);
  });
});

describe("fire and snakes", () => {
  it("kill at a touch", () => {
    for (const object of [6, 7]) {
      const seen = ticks(playing(screenOf(0, object), { x: 110 }), { right: true }, 30);
      expect(seen.at(-1).phase).toBe(PHASE.DYING);
    }
  });
});
