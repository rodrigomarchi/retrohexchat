import { describe, expect, it } from "vitest";
import {
  EDGE_MAX,
  EDGE_MIN,
  EVENT,
  GROUND_Y,
  PHASE,
  SCREENS,
  SEED,
  START_X,
  TREASURE,
  UNDER_Y,
} from "../../../../js/lib/games/hex_jungle/protocol.js";
import { stepLeft, stepRight } from "../../../../js/lib/games/hex_jungle/world.js";
import {
  changeScreen,
  collectTreasure,
  createInitialState,
  loseLife,
  respawn,
  stepRespawn,
  shiftingInset,
  vineX,
  stepPlayer,
  logsFor,
  stepTick,
  tickClock,
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

// ── Vines, ladders and the tunnel ──

describe("a vine", () => {
  const tar = screenOf(2, FIRE);

  it("swings between x 44 and 106 every 285 ticks", () => {
    expect(vineX(0)).toBe(106);
    expect(vineX(142)).toBe(44);
    expect(vineX(285)).toBe(106);
  });

  it("is caught by jumping into it, and carries the player over the pit", () => {
    const caught = after(playing(tar, { x: 110 }, { tick: 0 }), { jump: true, left: true }, 1);
    expect(caught.player.onVine).toBe(true);

    const swung = ticks(caught, {}, 120);
    expect(swung.every((s) => s.phase === PHASE.PLAYING && s.player.onVine)).toBe(true);
    swung.forEach((s) => expect(s.player.x).toBe(vineX(s.tick - 1)));
  });

  it("is not caught by walking under it", () => {
    expect(after(playing(tar, { x: 110 }, { tick: 0 }), {}, 1).player.onVine).toBe(false);
  });

  it("lets go on down, and the player drops the way it was swinging", () => {
    const caught = after(playing(tar, { x: 110 }, { tick: 0 }), { jump: true, left: true }, 1);
    const late = after(caught, {}, 129);
    const landed = after(after(late, { down: true }, 1), {}, 40);
    expect(landed.player.onVine).toBe(false);
    expect(landed.player.y).toBe(GROUND_Y);
    expect(landed.player.x).toBeLessThan(44);
    expect(landed.phase).toBe(PHASE.PLAYING);
  });
});

describe("a ladder", () => {
  const ladder = screenOf(0, FIRE);

  it("is climbed down a rung every 8 ticks into the tunnel, with no hole to pay for", () => {
    const on = after(playing(ladder, { x: 70 }), { down: true }, 1);
    expect(on.player).toMatchObject({ climbing: true, x: 76 });

    const seen = ticks(on, { down: true }, 88);
    const ys = seen.map((s) => s.player.y);
    expect(new Set(ys.slice(0, 9)).size).toBe(2);
    const bottom = seen.at(-1);
    expect(bottom.player).toMatchObject({ y: UNDER_Y, climbing: false });
    expect(bottom.underground).toBe(true);
    expect(bottom.score).toBe(2000);
  });

  it("is out of reach a step away", () => {
    expect(after(playing(ladder, { x: 66 }), { down: true }, 1).player.climbing).toBeFalsy();
  });

  it("is climbed up from the tunnel, and stepped off at the top with a hop", () => {
    const below = playing(ladder, { x: 74, y: UNDER_Y }, { underground: true });
    const on = after(below, { up: true }, 1);
    expect(on.player).toMatchObject({ climbing: true, x: 76 });

    const top = after(on, { up: true }, 88);
    expect(top.player).toMatchObject({ climbing: true, y: GROUND_Y });
    expect(top.underground).toBe(false);

    const off = after(after(top, { right: true }, 1), {}, 40);
    expect(off.player.climbing).toBe(false);
    expect(off.player.y).toBe(GROUND_Y);
    expect(off.player.x).toBeGreaterThan(82);
    expect(off.underground).toBe(false);
    expect(off.phase).toBe(PHASE.PLAYING);
  });

  it("is pushed down a rung by a log", () => {
    const climbing = playing(
      screenOf(0, 4),
      { x: 76, y: GROUND_Y + 2, climbing: true },
      {
        logs: [{ x: 76 }],
      },
    );
    const pushed = after(climbing, {}, 1);
    expect(pushed.player.y).toBeGreaterThan(GROUND_Y + 2);
  });
});

describe("the tunnel", () => {
  const tunnel = (screen, player) =>
    playing(screen, { y: UNDER_Y, ...player }, { underground: true });

  it("has a wall on the side bit 7 names, which pushes the player back", () => {
    const right = ticks(tunnel(0b10000110, { x: 100 }), { right: true }, 100);
    expect(Math.max(...right.map((s) => s.player.x))).toBeLessThanOrEqual(132);
    expect(right.at(-1).phase).toBe(PHASE.PLAYING);

    const left = ticks(tunnel(0b00000110, { x: 40 }), { left: true }, 100);
    expect(Math.min(...left.map((s) => s.player.x))).toBeGreaterThanOrEqual(25);
  });

  it("is three screens of the jungle's for each of its own", () => {
    const entered = after(tunnel(screenOf(2, 0), { x: EDGE_MAX }), { right: true }, 1);
    expect(entered.screen).toBe(stepRight(stepRight(stepRight(screenOf(2, 0)))));
  });

  it("has a scorpion that creeps a pixel every 8 ticks toward the player", () => {
    const start = tunnel(screenOf(2, 0), { x: 20 });
    expect(start.scorpionX).toBe(76);
    expect(after(start, {}, 80).scorpionX).toBe(66);
    expect(after(tunnel(screenOf(2, 0), { x: 140 }), {}, 80).scorpionX).toBe(86);
  });

  it("dies at the scorpion's touch", () => {
    expect(after(tunnel(screenOf(2, 0), { x: 74 }), {}, 1).phase).toBe(PHASE.DYING);
  });
});

// ── Treasures, the clock and lives ──

describe("treasures", () => {
  // Scene 5 holds the treasure its object's two low bits name.
  const ring = screenOf(5, 3);
  const standingOnIt = (rest = {}) => playing(ring, { x: 122 }, { tick: 30, ...rest });

  it("are worth their own points when touched, once", () => {
    const taken = collectTreasure(standingOnIt());
    expect(taken.score).toBe(2000 + TREASURE.RING.points);
    expect(taken.treasures).toBe(1);
    expect(collectTreasure(taken).score).toBe(taken.score);
  });

  it("stay taken when the screen comes round again", () => {
    let state = collectTreasure(standingOnIt());
    for (let i = 0; i < SCREENS; i++) state = changeScreen(state, 1);
    expect(state.screen).toBe(ring);
    expect(collectTreasure({ ...state, player: { ...state.player, x: 122 } }).score).toBe(
      state.score,
    );
  });

  it("end the expedition when the 32nd is taken", () => {
    const last = collectTreasure(standingOnIt({ treasures: 31 }));
    expect(last.treasures).toBe(32);
    expect(last.phase).toBe(PHASE.FINISHED);
  });

  it("are out of reach from the tunnel", () => {
    const below = standingOnIt({ underground: true });
    expect(collectTreasure({ ...below, player: { ...below.player, y: UNDER_Y } }).score).toBe(2000);
  });
});

describe("the clock", () => {
  it("counts down a second every 60 ticks once running", () => {
    let state = playing(screenOf(0, FIRE));
    for (let i = 0; i < 60; i++) state = tickClock(state);
    expect(state.timerTicks).toBe(20 * 60 * 60 - 60);

    const stopped = { ...state, clockRunning: false };
    expect(tickClock(stopped).timerTicks).toBe(stopped.timerTicks);
  });

  it("ends the expedition at zero", () => {
    const last = tickClock({ ...playing(screenOf(0, FIRE)), timerTicks: 1 });
    expect(last.timerTicks).toBe(0);
    expect(last.phase).toBe(PHASE.FINISHED);
  });
});

describe("a life lost", () => {
  it("is taken from the three", () => {
    expect(loseLife(playing(screenOf(0, FIRE))).lives).toBe(2);
  });

  it("drops the player from the trees at x 20, back to their feet in about a second", () => {
    const dead = { ...playing(screenOf(0, FIRE), { x: 120 }), phase: PHASE.DYING, logs: [] };
    let state = respawn(dead);
    expect(state.player).toMatchObject({ x: START_X, y: GROUND_Y - 66 });
    expect(state.phase).toBe(PHASE.RESPAWN);
    let steps = 0;
    while (state.phase === PHASE.RESPAWN && steps < 200) {
      state = stepRespawn(state);
      steps++;
    }
    expect(steps).toBe(66);
    expect(state.player.y).toBe(GROUND_Y);
    expect(state.phase).toBe(PHASE.PLAYING);
  });

  it("in the tunnel drops them from its roof, and sends the scorpion back to the middle", () => {
    const dead = {
      ...playing(screenOf(2, 0), { x: 74, y: UNDER_Y }, { underground: true, scorpionX: 74 }),
      phase: PHASE.DYING,
    };
    const state = respawn(dead);
    expect(state.player).toMatchObject({ x: START_X, y: 64 });
    expect(state.underground).toBe(true);
    expect(state.scorpionX).toBe(76);
  });
});

// ── What a tick says happened, for the sounds ──

describe("events", () => {
  const fired = (state, bit) => (state.events & bit) !== 0;

  it("a jump, on the tick it leaves the ground only", () => {
    const start = playing(screenOf(0, FIRE), { x: 100 });
    const seen = ticks(start, { jump: true }, 3);
    expect(seen.slice(1).map((s) => fired(s, EVENT.JUMP))).toEqual([true, false, false]);
  });

  it("the vine caught", () => {
    const caught = after(playing(screenOf(2, FIRE), { x: 110 }, { tick: 0 }), { jump: true }, 1);
    expect(fired(caught, EVENT.VINE)).toBe(true);
  });

  it("a fall through a hole", () => {
    const seen = ticks(playing(screenOf(0, FIRE), { x: 70 }), { right: true }, 8);
    expect(seen.filter((s) => fired(s, EVENT.HOLE))).toHaveLength(1);
  });

  it("a death", () => {
    const seen = ticks(playing(screenOf(0, FIRE), { x: 110 }), { right: true }, 30);
    const died = seen.find((s) => s.phase === PHASE.DYING);
    expect(fired(died, EVENT.DEATH)).toBe(true);
  });

  it("a treasure taken", () => {
    const taken = after(playing(screenOf(5, 0), { x: 121 }, { tick: 30 }), { right: true }, 2);
    expect(taken.treasures).toBe(1);
    expect(
      ticks(playing(screenOf(5, 0), { x: 121 }, { tick: 30 }), { right: true }, 2).some((s) =>
        fired(s, EVENT.TREASURE),
      ),
    ).toBe(true);
  });

  it("a wall hit", () => {
    const tunnel = playing(0b10000110, { x: 130, y: UNDER_Y }, { underground: true });
    expect(ticks(tunnel, { right: true }, 10).some((s) => fired(s, EVENT.WALL))).toBe(true);
  });

  it("nothing, on a quiet tick", () => {
    expect(after(playing(screenOf(0, FIRE), { x: 20 }), {}, 1).events).toBe(0);
  });
});

// ── Found in review ──

describe("a pit that shuts on a sinking player", () => {
  it("does not lift them back out: they sink on to the end", () => {
    // Open at tick 250; the edge passes x 50 as it narrows from tick 256.
    const seen = ticks(playing(screenOf(6, FIRE), { x: 50 }, { tick: 250 }), {}, 40);
    expect(seen.at(-1).phase).toBe(PHASE.DYING);
  });

  it("nor do a crocodile's jaws shutting under them", () => {
    // Jaws open at tick 250: x 58 is water; at tick 256 they shut and x 58 is a head.
    const seen = ticks(playing(screenOf(4, 0), { x: 58 }, { tick: 250 }), {}, 40);
    expect(seen.at(-1).phase).toBe(PHASE.DYING);
  });
});

describe("a tunnel wall met from outside", () => {
  it("stops a player coming from the screen's left edge", () => {
    const tunnel = playing(0b00000110, { x: 8, y: UNDER_Y }, { underground: true });
    const seen = ticks(tunnel, { right: true }, 60);
    expect(Math.max(...seen.map((s) => s.player.x))).toBeLessThanOrEqual(13);
  });

  it("stops a player coming from the screen's right edge", () => {
    const tunnel = playing(0b10000110, { x: 148, y: UNDER_Y }, { underground: true });
    const seen = ticks(tunnel, { left: true }, 60);
    expect(Math.min(...seen.map((s) => s.player.x))).toBeGreaterThanOrEqual(144);
  });
});

describe("the vine and a player already in the tar", () => {
  it("is out of reach once they are below the ground", () => {
    const sinking = playing(
      screenOf(2, FIRE),
      { x: 104, y: GROUND_Y + 10, jumpTick: 32 },
      { tick: 0 },
    );
    // The vine hangs at x 106 at tick 0: within reach, but the player is sinking.
    expect(after(sinking, {}, 1).player.onVine).toBe(false);
  });
});
