/**
 * Hex Jungle's computer player, for the autopilot: it makes the moves a
 * person would, through the same keys. Its map (`route.js`) says which way
 * the nearest treasure lies — along the jungle, or through the tunnels — and
 * on each screen it tries short runs of keys in the game's own simulation,
 * keeping the one that gets furthest that way without dying: over a log,
 * onto a vine, across a pit while it is shut, past a scorpion.
 *
 * It is not part of the game: only the e2e server's pages load it, to film
 * an expedition (`engine_loader.js`).
 *
 * @module games/hex_jungle/player
 */

import { stepTick } from "./physics.js";
import { GROUND_Y, JUMP_STEER_TICKS, LADDER, OBJECT_X, PHASE } from "./protocol.js";
import { wayToTreasure } from "./route.js";

/** A run of keys is tried in steps of this many ticks. */
const STEP = 8;
/** How many steps ahead it looks, and how many runs it keeps at each. */
const DEPTH = 6;
const WIDTH = 32;
const PER_FIRST = 3;
/** How many of the best run's steps it plays before looking again. */
const COMMIT = 2;
/** How long a run's end must be survivable, in ticks. */
const SAFE_FOR = 170;

const NONE = Object.freeze({ left: false, right: false, up: false, down: false, jump: false });
const keys = (held) => Object.freeze({ ...NONE, ...held });
/**
 * What can be done for a while: each held for a step, and a pixel's walk or
 * wait — a jump over a snake must leave from one pixel and no other.
 */
const CHOICES = [
  [keys({}), STEP],
  [keys({ left: true }), STEP],
  [keys({ right: true }), STEP],
  [keys({ jump: true }), STEP],
  [keys({ jump: true, left: true }), STEP],
  [keys({ jump: true, right: true }), STEP],
  [keys({ down: true }), STEP],
  [keys({ up: true }), STEP],
  [keys({}), 2],
  [keys({ left: true }), 2],
  [keys({ right: true }), 2],
];

const DEAD = -1e9;
const ARRIVED = 1e6;

const placeOf = (state, heading) => ({
  screen: state.screen,
  underground: state.underground,
  heading: state.underground ? heading : 0,
});

/** `steps` ticks of the same keys; stops early on a death or a new place. */
function run(state, held, ticks) {
  let next = state;
  for (let i = 0; i < ticks; i++) {
    next = stepTick(next, held);
    if (next.phase !== PHASE.PLAYING) return next;
    if (next.screen !== state.screen || next.underground !== state.underground) return next;
    if (next.treasures !== state.treasures) return next;
  }
  return next;
}

/** Whether the place a state stands in is the one the move is for. */
const arrived = (state, from, goal) =>
  state.treasures > from.treasures ||
  (goal.move.kind !== "treasure" &&
    state.screen === goal.next.screen &&
    state.underground === goal.next.underground);

/** How good a state is for the move at hand: further along it, unhurt. */
function worth(state, from, goal, tick) {
  if (state.phase === PHASE.DYING) return DEAD;
  if (arrived(state, from, goal)) return ARRIVED - tick;
  if (state.screen !== from.screen || state.underground !== from.underground) return DEAD / 2;
  const { x, y, climbing } = state.player;
  const hurt = (from.score - state.score) * 0.3;
  const { kind, dir } = goal.move;
  let along;
  if (kind === "exit" || kind === "turn") {
    const toward = kind === "turn" ? goal.next.heading : dir;
    along = toward > 0 ? x : 160 - x;
    // Down a ladder first, when the tunnel is where the way goes.
    if (state.underground && climbing) along = y - 200;
  } else if (kind === "treasure") {
    along = -Math.abs(x - (OBJECT_X + 2));
  } else if (kind === "descend") {
    along = -Math.abs(x - LADDER.x) + (climbing ? 40 + y : 0);
  } else {
    along = -Math.abs(x - LADDER.x) + (climbing ? 200 - y : 0);
  }
  return along - hurt;
}

/** A jump's length in ticks, and a little more: a hop's rhythm. */
const HOP = 34;

/**
 * `ticks` ticks of a plain way of carrying on: the keys held, and with
 * `hop` a fresh press of jump at every hop's start.
 */
function carryOn(state, held, hop, ticks) {
  let next = state;
  for (let i = 0; i < ticks; i++) {
    const keysNow = hop ? { ...held, jump: i % HOP < 2 } : held;
    next = stepTick(next, keysNow);
    if (next.phase !== PHASE.PLAYING) return next;
    if (next.screen !== state.screen || next.underground !== state.underground) return next;
    if (next.treasures !== state.treasures) return next;
  }
  return next;
}

/**
 * Whether, from here, some plain way of carrying on keeps the player alive:
 * standing, walking either way, or hopping either way — crocodiles' heads
 * are crossed one hop at a time.
 */
function survivable(state, goal) {
  const toward = goal.move.dir ?? goal.next.heading ?? 0;
  const ahead = toward < 0 ? { left: true } : { right: true };
  const back = toward < 0 ? { right: true } : { left: true };
  const ways = [
    [keys({}), false],
    [keys(ahead), false],
    [keys(back), false],
    [keys(ahead), true],
    [keys(back), true],
  ];
  return ways.some(([held, hop]) => carryOn(state, held, hop, SAFE_FOR).phase !== PHASE.DYING);
}

/**
 * Whether a state is already lost, whatever is pressed next: a jump past
 * its steering lands where it lands, and a player sunk below the ground
 * sinks on.
 */
function doomed(state) {
  if (state.phase === PHASE.DYING) return true;
  const { player } = state;
  const sinking = !state.underground && player.y > GROUND_Y && player.jumpTick === null;
  const flying = player.jumpTick !== null && player.jumpTick > JUMP_STEER_TICKS;
  if (!sinking && !flying) return false;
  let next = state;
  for (let i = 0; i < 48 && next.phase === PHASE.PLAYING; i++) {
    next = stepTick(next, NONE);
    if (next.screen !== state.screen || next.underground !== state.underground) return false;
    const p = next.player;
    if (p.onVine || (p.jumpTick === null && p.y === GROUND_Y)) return false;
    if (state.underground && p.jumpTick === null) return false;
  }
  return next.phase === PHASE.DYING;
}

/**
 * The runs kept for the next step: the best few of each first step, so that
 * waiting or stepping back stays in view while running on looks better —
 * the run that looks best can be the one a pit opens under — then the best
 * of the rest.
 */
function keepVaried(nodes) {
  nodes.sort((a, b) => b.value - a.value);
  const perFirst = new Map();
  const kept = [];
  const rest = [];
  for (const node of nodes) {
    const first = `${CHOICES.indexOf(node.path[0])}|${node.state.player.onVine}`;
    const count = perFirst.get(first) ?? 0;
    if (count < PER_FIRST) {
      perFirst.set(first, count + 1);
      kept.push(node);
    } else rest.push(node);
  }
  return [...kept, ...rest.slice(0, Math.max(0, WIDTH - kept.length))];
}

/**
 * The best run of keys from `state` for the move at hand, as the keys of
 * each step.
 */
function plan(state, goal) {
  let beam = [{ state, path: [], value: worth(state, state, goal, 0), done: false }];
  const leaves = [];
  for (let depth = 0; depth < DEPTH; depth++) {
    const next = new Map();
    for (const node of beam) {
      if (node.done) {
        leaves.push(node);
        continue;
      }
      for (const choice of CHOICES) {
        const after = run(node.state, choice[0], choice[1]);
        if (doomed(after)) continue;
        const tick = after.tick - state.tick;
        const value = worth(after, state, goal, tick);
        const done = value <= DEAD / 2 || value >= ARRIVED - 1e5 || after.phase !== PHASE.PLAYING;
        const p = after.player;
        const key = `${after.screen}|${after.underground}|${p.x}|${p.y}|${p.jumpTick}|${p.onVine}|${p.climbing}|${after.jumpHeld}`;
        const seen = next.get(key);
        if (seen && seen.value >= value) continue;
        next.set(key, { state: after, path: [...node.path, choice], value, done });
      }
    }
    beam = keepVaried([...next.values()]);
  }
  leaves.push(...beam);
  leaves.sort((a, b) => b.value - a.value);
  for (const leaf of leaves) {
    if (leaf.value <= DEAD / 2) break;
    if (leaf.value >= ARRIVED - 1e5 || survivable(leaf.state, goal)) return leaf.path;
  }
  return leaves[0]?.path ?? [];
}

/** What a tick's state must look like for the plan made for it to still hold. */
const signature = (state) => {
  const p = state.player;
  return `${state.tick}|${state.screen}|${state.underground}|${p.x}|${p.y}|${p.jumpTick}|${p.onVine}|${p.climbing}|${state.jumpHeld}`;
};

/**
 * The keys of a plan, tick by tick, with the state each is meant for: the
 * game's clock and a page's frames need not keep step — a slow frame runs two
 * ticks on one press — so each press is checked against the state it meets.
 */
function schedule(state, path) {
  const steps = [];
  let next = state;
  for (const [held, ticks] of path) {
    for (let i = 0; i < ticks; i++) {
      steps.push({ tick: next.tick, expect: signature(next), held });
      next = stepTick(next, held);
      if (next.phase !== PHASE.PLAYING) return steps;
    }
  }
  return steps;
}

/**
 * @returns {{ nextInputs: (observed: { state: object }) => object | null }}
 */
export function createHexJunglePlayer() {
  let heading = -1;
  let goal = null;
  let goalFrom = null;
  let steps = [];

  const place = (state) => placeOf(state, heading);
  const wayFrom = (state) =>
    wayToTreasure(place(state), state.taken) ?? {
      move: { kind: "exit", dir: -1 },
      next: { ...place(state), screen: -1 },
    };

  return {
    nextInputs({ state }) {
      if (!state || state.phase !== PHASE.PLAYING) {
        steps = [];
        goal = null;
        return NONE;
      }
      const here = place(state);
      const moved =
        !goal ||
        !goalFrom ||
        goalFrom.screen !== here.screen ||
        goalFrom.underground !== here.underground ||
        goalFrom.treasures !== state.treasures;
      if (moved) {
        // Underground, the way it was heading is kept from the move that led there.
        if (goal?.next?.underground && state.underground) heading = goal.next.heading;
        else if (state.underground && !goal) heading = -1;
        goal = wayFrom(state);
        // Turning round underground is a change of mind, not a walk.
        if (goal.move.kind === "turn") {
          heading = goal.next.heading;
          goal = wayFrom(state);
        }
        goalFrom = {
          screen: state.screen,
          underground: state.underground,
          treasures: state.treasures,
        };
        steps = [];
      }
      const now = signature(state);
      while (steps.length > 0 && steps[0].tick < state.tick) steps.shift();
      if (steps.length === 0 || steps[0].expect !== now) {
        steps = schedule(state, plan(state, goal).slice(0, COMMIT));
      }
      return steps.shift()?.held ?? NONE;
    },
  };
}
