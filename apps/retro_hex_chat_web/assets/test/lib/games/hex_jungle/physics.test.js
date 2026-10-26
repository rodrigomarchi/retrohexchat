import { describe, expect, it } from "vitest";
import {
  EDGE_MAX,
  EDGE_MIN,
  GROUND_Y,
  SCREENS,
  SEED,
  START_X,
} from "../../../../js/lib/games/hex_jungle/protocol.js";
import { stepLeft, stepRight } from "../../../../js/lib/games/hex_jungle/world.js";
import {
  changeScreen,
  createInitialState,
  stepPlayer,
} from "../../../../js/lib/games/hex_jungle/physics.js";

const NONE = { left: false, right: false, up: false, down: false, jump: false };
const held = (keys) => ({ ...NONE, ...keys });

/** Run the player for `ticks` with the same keys held throughout. */
function run(state, keys, ticks) {
  let current = state;
  for (let i = 0; i < ticks; i++) current = stepPlayer(current, held(keys));
  return current;
}

/**
 * A state on a tar-pit screen. stepPlayer only moves the player — what the
 * ground does to them is stepHazards' — so any screen will do.
 */
const onScreen = (player = {}) => {
  const state = createInitialState();
  return { ...state, screen: 0b00010000, player: { ...state.player, ...player } };
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
    const state = onScreen({ x: 60 });
    let jumped = stepPlayer(state, held({ jump: true, right: true }));
    jumped = stepPlayer(jumped, held({ right: true }));
    const turned = run(jumped, { left: true }, 31);
    expect(turned.player.x).toBe(60 + 16);
    expect(turned.player.y).toBe(GROUND_Y);
  });

  it("can set its direction in the jump's first two ticks", () => {
    const state = onScreen({ x: 60 });
    const late = run(stepPlayer(state, held({ jump: true })), { right: true }, 32);
    expect(late.player.x).toBe(60 + 16);

    const still = run(stepPlayer(state, held({ jump: true })), {}, 2);
    expect(run(still, { left: true }, 30).player.x).toBe(60);
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
