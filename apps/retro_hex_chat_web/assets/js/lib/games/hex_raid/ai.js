/**
 * Deterministic opponent controller for Hex Raid solo sessions.
 * The controller emits the same held-input shape used by the P2P guest path,
 * keeping solo and P2P on the same host-authoritative simulation.
 *
 * @module games/hex_raid_ai
 */

import { normalizeRaidAIDifficulty } from "./difficulty.js";
import { ENEMY_TYPE, GAME_MODE, PHASE } from "./protocol.js";
import {
  CANVAS_H,
  CANVAS_W,
  JET_LATERAL_SPEED,
  JET_RADIUS,
  MAX_MINES_PER_PLAYER,
  MINE_DRIFT,
  MINE_RADIUS,
  MISSILE_SPEED,
  SPEED_BASE,
  SPEED_MAX,
  SPEED_MIN,
  getBankAtWorld,
} from "./physics.js";
import { TableAI, clamp, createCommitment, createDelayedView, createPerThing } from "../core/ai.js";

const SAFE_MARGIN = JET_RADIUS + 18;
/** How far aside a thing ahead still counts as in the jet's lane. */
const WATCH_X = 60;
/** How close a jet's centre comes to an enemy's when they meet. */
const CRASH_REACH = JET_RADIUS + 8;
/** How close a jet's centre comes to a mine's when it goes off. */
const MINE_REACH = JET_RADIUS + MINE_RADIUS;
/** How far from a bank the spots the AI weighs keep. */
const BANK_MARGIN = JET_RADIUS + 6;
/** How far ahead of the jet the banks are read, as the river brings them. */
const BANK_LOOKAHEAD_Y = 40;
/** The spacing of the spots across the river the AI weighs. */
const LANE_STEP = 6;
/** How often, in frames, a crossing is looked at along its way past the jet. */
const CROSSING_STEP = 2;
/** How fast an enemy jet dives, on top of the river's own pace. */
const ENEMY_JET_DIVE = 3;
const TARGET_LOOKAHEAD_Y = 120;
const OWN_FIELDS = ["X", "Y", "Speed", "Fuel", "Alive", "MissileCooldown", "MineCooldown"];

const NEUTRAL_INPUTS = Object.freeze({
  left: false,
  right: false,
  accel: false,
  decel: false,
  fire: false,
  mine: false,
});

/**
 * How each difficulty flies. It sees the river `reaction` frames late and
 * plans again every `interval` frames; every plan misses its spot by up to
 * `error` pixels, one miss kept for as long as it chases the same target. It
 * steers clear of what comes within `threatY` ahead, from where it will be
 * when it crosses the jet's line, leaving `clearance` pixels to spare,
 * and fires at an enemy up to `fireX` aside of its nose — of where the enemy
 * will be, when it `lead`s its shots. It notices a rival's mine
 * `mineNotice` of the time, once per mine, and drops one of its own, with
 * `mineOdds`, when the rival flies within `mineX` of its lane — trying again
 * no sooner than `mineCd` frames later. A shot is taken the same way: one
 * draw of `fireOdds` per chance, the next chance `fireCd` frames later.
 * Every column is ordered from easy to hard; `cruise` is the pace it flies
 * at, not a strength.
 */
export const RAID_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    reaction: 18,
    interval: 12,
    error: 30,
    deadzone: 10,
    threatY: 110,
    clearance: 3,
    fuelAt: 105,
    fuelY: 210,
    fireY: 270,
    fireX: 24,
    fireOdds: 0.6,
    fireCd: 20,
    mineOdds: 0.15,
    mineCd: 240,
    mineX: 30,
    mineNotice: 0.55,
    lead: 0,
    cruise: SPEED_BASE,
  }),
  normal: Object.freeze({
    reaction: 12,
    interval: 8,
    error: 20,
    deadzone: 8,
    threatY: 125,
    clearance: 4,
    fuelAt: 170,
    fuelY: 340,
    fireY: 340,
    fireX: 14,
    fireOdds: 0.8,
    fireCd: 16,
    mineOdds: 0.35,
    mineCd: 160,
    mineX: 20,
    mineNotice: 0.8,
    lead: 0.2,
    cruise: SPEED_BASE,
  }),
  hard: Object.freeze({
    reaction: 4,
    interval: 3,
    error: 3,
    deadzone: 4,
    threatY: 135,
    clearance: 7,
    fuelAt: 220,
    fuelY: 420,
    fireY: 420,
    fireX: 8,
    fireOdds: 0.9,
    fireCd: 12,
    mineOdds: 0.6,
    mineCd: 90,
    mineX: 14,
    mineNotice: 0.95,
    lead: 0.7,
    cruise: SPEED_BASE + 1,
  }),
});

export { normalizeRaidAIDifficulty };

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @param {number} [options.seed]
 * @returns {HexRaidAI}
 */
export function createHexRaidAI(options = {}) {
  return new HexRaidAI(options);
}

export class HexRaidAI extends TableAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   * @param {number} [options.seed]
   */
  constructor(options = {}) {
    super(options, normalizeRaidAIDifficulty, RAID_AI_DIFFICULTIES, 0x72616964);
    this.fireCooldown = 0;
    this.mineCooldown = 0;
    this._target = null;
    this._view = createDelayedView();
    this._aim = createCommitment();
    this._noticed = createPerThing();
    this._moving = null;
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean, accel: boolean, decel: boolean, fire: boolean, mine: boolean}}
   */
  nextInputs(request = {}) {
    const { state, player } = this.startTurn(request);
    if (this.fireCooldown > 0) this.fireCooldown--;
    if (this.mineCooldown > 0) this.mineCooldown--;

    if (!state || state.phase !== PHASE.FLYING) {
      this._target = null;
      return NEUTRAL_INPUTS;
    }

    const config = this.rowFor(request);
    this._moving = withEnemyMotion(this._moving, state);
    const sight = delayedSight(this._view.see(this._moving, config.reaction), state, player);
    const seen = noticedMines(sight, player, this._noticed, () => this.rng() < config.mineNotice);

    if (!jetAlive(state, player)) {
      this._target = null;
      return NEUTRAL_INPUTS;
    }

    if (this.frame % config.interval === 0 || !this._target) {
      const miss = (key) => this._aim.hold(key, () => (this.rng() - 0.5) * config.error * 2);
      this._target = chooseRaidTarget(seen, player, config, miss);
    }

    const movement = movementInputs(state, player, this._target, config.deadzone);
    const fire = this._firePressed(seen, player, config);
    const mine = this._minePressed(seen, player, config);

    return { ...movement, fire, mine };
  }

  /**
   * @param {object} state
   * @param {1|2} player
   * @param {object} config
   * @returns {boolean}
   */
  _firePressed(state, player, config) {
    if (this.fireCooldown > 0) return false;
    if (!shouldFire(state, player, config)) return false;

    // One draw per chance: taken or let go, the next chance waits.
    this.fireCooldown = config.fireCd;
    return this.rng() <= config.fireOdds;
  }

  /**
   * @param {object} state
   * @param {1|2} player
   * @param {object} config
   * @returns {boolean}
   */
  _minePressed(state, player, config) {
    if (this.mineCooldown > 0) return false;
    if (!shouldDeployMine(state, player, config)) return false;

    // One draw per chance: dropped or let go, the next chance waits.
    this.mineCooldown = config.mineCd;
    return this.rng() <= config.mineOdds;
  }

  /** A new match: nothing seen, aimed at, noticed or waited for carries over. */
  forget() {
    super.forget?.();
    this.fireCooldown = 0;
    this.mineCooldown = 0;
    this._target = null;
    this._view.reset();
    this._aim.reset();
    this._noticed.reset();
    this._moving = null;
  }
}

/**
 * Where to fly next, and how fast. `miss` gives the plan's aim error for a
 * target, by the target's key; the spot it moves the plan to is still kept
 * inside the river.
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @param {(key: string) => number} [miss]
 * @returns {{x: number, targetSpeed: number, kind: string, key: string}}
 *   kind: "dodge", "fuel", "bridge", "attack" or "cruise"; key: the target's
 *   own, the same while it chases that one target
 */
export function chooseRaidTarget(
  state,
  player = 2,
  config = RAID_AI_DIFFICULTIES.normal,
  miss = () => 0,
) {
  const actor = jetState(state, player);
  if (!actor) return { x: CANVAS_W / 2, targetSpeed: SPEED_MIN, kind: "cruise", key: "cruise" };

  const goal = goalTarget(state, player, actor, config, miss);
  const x = clearLaneX(state, player, actor, goal.x, config);
  if (Math.abs(x - goal.x) <= config.deadzone) return goal;

  return {
    x,
    targetSpeed: Math.min(goal.targetSpeed, config.cruise),
    kind: "dodge",
    key: `dodge:${goal.key}`,
  };
}

/**
 * What the jet is after before anything in its way is counted: a bridge to
 * shoot down, fuel, an enemy to shoot, or the middle of the river ahead.
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number, y: number}} actor
 * @param {object} config
 * @param {(key: string) => number} miss
 * @returns {{x: number, targetSpeed: number, kind: string, key: string}}
 */
function goalTarget(state, player, actor, config, miss) {
  const threat = nearestThreat(state, player, config);
  if (threat?.bridge === true) {
    return {
      x: clampToSafeRiver(state, riverCenterAt(state, actor.y) + miss("dodge:bridge"), actor.y),
      targetSpeed: SPEED_MIN,
      kind: "dodge",
      key: "dodge:bridge",
    };
  }

  const fuel = nearestFuelTarget(state, player, config);
  if (fuel) {
    const key = `fuel:${fuel.id}`;
    return {
      x: clampToSafeRiver(state, fuel.x + miss(key), fuel.y),
      targetSpeed: fuel.y > actor.y - 80 ? SPEED_MIN : SPEED_BASE,
      kind: "fuel",
      key,
    };
  }

  const bridge = bridgeTarget(state, player, miss);
  if (bridge) return bridge;

  const attack = attackTarget(state, player, config, miss);
  if (attack) return attack;

  const lookY = Math.max(0, actor.y - TARGET_LOOKAHEAD_Y);
  return {
    x: clampToSafeRiver(state, riverCenterAt(state, lookY) + miss("cruise"), lookY),
    targetSpeed: config.cruise,
    kind: "cruise",
    key: "cruise",
  };
}

/**
 * The spot across the river, nearest `goalX`, that the jet can fly to
 * without meeting anything coming down within `config.threatY`: each enemy
 * and rival mine is followed to where it will be while it crosses the jet's
 * line, the jet to where it will be on its way to the spot. With no spot
 * clear, the one that meets something latest.
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number, y: number, speed: number}} actor
 * @param {number} goalX
 * @param {object} config
 * @returns {number}
 */
function clearLaneX(state, player, actor, goalX, config) {
  const crossings = crossingsAhead(state, player, actor, config);
  if (crossings.length === 0) return goalX;

  // The banks where the jet is and where the river brings it next.
  const here = safeBankAt(state, actor.y);
  const next = safeBankAt(state, actor.y - BANK_LOOKAHEAD_Y);
  const left = Math.max(here.leftX, next.leftX) + BANK_MARGIN;
  const right = Math.min(here.rightX, next.rightX) - BANK_MARGIN;
  const spots = [clamp(goalX, left, right)];
  for (let x = left; x <= right; x += LANE_STEP) spots.push(x);

  return (
    nearestClearSpot(spots, actor.x, goalX, crossings, config.clearance) ??
    nearestClearSpot(spots, actor.x, goalX, crossings, 0) ??
    latestMeetingSpot(spots, actor.x, crossings)
  );
}

/**
 * The spot nearest `goalX` that keeps `spare` pixels clear of every crossing
 * on the way, or null when none does.
 * @param {number[]} spots
 * @param {number} fromX
 * @param {number} goalX
 * @param {{from: number, to: number, reach: number, xAt: (t: number) => number}[]} crossings
 * @param {number} spare
 * @returns {number | null}
 */
function nearestClearSpot(spots, fromX, goalX, crossings, spare) {
  let best = null;
  for (const spot of spots) {
    if (firstMeeting(fromX, spot, crossings, spare) !== null) continue;
    if (best === null || Math.abs(spot - goalX) < Math.abs(best - goalX)) best = spot;
  }
  return best;
}

/**
 * With every spot meeting something, the one that meets it latest.
 * @param {number[]} spots
 * @param {number} fromX
 * @param {{from: number, to: number, reach: number, xAt: (t: number) => number}[]} crossings
 * @returns {number}
 */
function latestMeetingSpot(spots, fromX, crossings) {
  let best = spots[0];
  let latest = -1;
  for (const spot of spots) {
    const meets = firstMeeting(fromX, spot, crossings, 0);
    if (meets > latest) {
      best = spot;
      latest = meets;
    }
  }
  return best;
}

/**
 * When the jet, flying from `fromX` to `spot`, first comes within a
 * crossing's reach and `spare` pixels more of it, in frames from now; null
 * when it never does.
 * @param {number} fromX
 * @param {number} spot
 * @param {{from: number, to: number, reach: number, xAt: (t: number) => number}[]} crossings
 * @param {number} spare
 * @returns {number | null}
 */
function firstMeeting(fromX, spot, crossings, spare) {
  let first = null;
  const distance = spot - fromX;
  const travel = Math.abs(distance) / JET_LATERAL_SPEED;
  for (const crossing of crossings) {
    for (let t = crossing.from; t <= crossing.to; t += CROSSING_STEP) {
      const jetX = t >= travel ? spot : fromX + Math.sign(distance) * JET_LATERAL_SPEED * t;
      if (Math.abs(jetX - crossing.xAt(t)) < crossing.reach + spare) {
        if (first === null || t < first) first = t;
        break;
      }
    }
  }
  return first;
}

/**
 * Every enemy and rival mine that will cross the jet's line, with the frames
 * it spends crossing it and where it is on each of them.
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number, y: number, speed: number}} actor
 * @param {object} config
 * @returns {{from: number, to: number, reach: number, xAt: (t: number) => number}[]}
 */
function crossingsAhead(state, player, actor, config) {
  const river = Math.max(scrollPace(state), SPEED_MIN);
  const crossings = [];
  const add = (thing, pace, vx, reach) => {
    const dy = actor.y - thing.y;
    if (dy > config.threatY || dy < -reach) return;
    const from = Math.max(0, (dy - reach) / pace);
    const to = (dy + reach) / pace;
    // A boat turns back where it meets the banks of its own stretch of river.
    const bank = safeBankAt(state, thing.y);
    const low = Math.min(thing.x, bank.leftX + 20);
    const high = Math.max(thing.x, bank.rightX - 20);
    const xAt = (t) => bounced(thing.x + vx * t, low, high);
    crossings.push({ from, to, reach, xAt });
  };

  for (const enemy of Array.isArray(state.enemies) ? state.enemies : []) {
    if (!enemy.alive || !onScreen(enemy)) continue;
    const dive = enemy.type === ENEMY_TYPE.JET ? ENEMY_JET_DIVE : 0;
    add(enemy, river + dive, enemy.vx || 0, CRASH_REACH);
  }
  for (const mine of Array.isArray(state.mines) ? state.mines : []) {
    if (!mine.active || mine.owner === player) continue;
    add(mine, river * MINE_DRIFT, 0, MINE_REACH);
  }
  return crossings;
}

/** The river's pace: the faster of the jets in play sets it. */
function scrollPace(state) {
  const speed1 = state.jet1Alive ? state.jet1Speed : 0;
  const speed2 = state.jet2Alive ? state.jet2Speed : 0;
  return Math.max(speed1, speed2);
}

/** `x` folded back inside [low, high], as a boat bouncing off the banks. */
function bounced(x, low, high) {
  const span = high - low;
  if (span <= 0) return low;
  const period = span * 2;
  const folded = (((x - low) % period) + period) % period;
  return low + (folded <= span ? folded : period - folded);
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number, targetSpeed?: number}|null} target
 * @param {number} deadzone
 * @returns {{left: boolean, right: boolean, accel: boolean, decel: boolean, fire: boolean, mine: boolean}}
 */
export function movementInputs(state, player, target, deadzone) {
  const actor = jetState(state, player);
  if (!actor || !target) return NEUTRAL_INPUTS;

  const dx = target.x - actor.x;
  const targetSpeed = clamp(target.targetSpeed ?? SPEED_BASE, SPEED_MIN, SPEED_MAX);

  return {
    left: dx < -deadzone,
    right: dx > deadzone,
    accel: actor.speed < targetSpeed,
    decel: actor.speed > targetSpeed,
    fire: false,
    mine: false,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, y: number, kind: string}|null}
 */
export function nearestFuelTarget(state, player = 2, config = RAID_AI_DIFFICULTIES.normal) {
  const actor = jetState(state, player);
  if (!actor || actor.fuel > config.fuelAt) return null;

  const fuels = Array.isArray(state.fuels) ? state.fuels : [];
  return lowest(fuels, (fuel) => {
    if (!fuel.available || !onScreen(fuel)) return null;
    const dy = actor.y - fuel.y;
    if (dy < 0 || dy > config.fuelY) return null;
    return dy + Math.abs(actor.x - fuel.x) * 0.55;
  });
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {boolean}
 */
export function shouldFire(state, player = 2, config = RAID_AI_DIFFICULTIES.normal) {
  const actor = jetState(state, player);
  if (!actor || !actor.alive) return false;
  if (missileActive(state, player) || missileCooldown(state, player) > 0) return false;
  if (fuelInLineOfFire(state, actor)) return false;

  if (
    state.bridgeActive &&
    state.bridgeY >= 0 &&
    state.bridgeY < actor.y &&
    actor.y - state.bridgeY < config.fireY
  ) {
    return true;
  }

  const enemies = Array.isArray(state.enemies) ? state.enemies : [];
  return enemies.some((enemy) => {
    if (!enemy.alive || !onScreen(enemy)) return false;
    const dy = actor.y - enemy.y;
    return (
      dy > 0 && dy < config.fireY && Math.abs(actor.x - aimX(enemy, dy, config)) <= config.fireX
    );
  });
}

/** How close a missile passes to a fuel station and still blows it up. */
const FUEL_SHOT_REACH = 12 + 4;

/**
 * Whether a fuel station sits ahead in the missile's path: a shot now would
 * blow up fuel the jet may need.
 * @param {object} state
 * @param {{x: number, y: number}} actor
 * @returns {boolean}
 */
function fuelInLineOfFire(state, actor) {
  const fuels = Array.isArray(state.fuels) ? state.fuels : [];
  return fuels.some(
    (fuel) => fuel.available && fuel.y < actor.y && Math.abs(fuel.x - actor.x) < FUEL_SHOT_REACH,
  );
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {boolean}
 */
export function shouldDeployMine(state, player = 2, config = RAID_AI_DIFFICULTIES.normal) {
  if (state.mode === GAME_MODE.PACIFIST) return false;

  const actor = jetState(state, player);
  const opponent = jetState(state, player === 1 ? 2 : 1);
  if (!actor || !opponent || !actor.alive || !opponent.alive) return false;
  if (state[player === 1 ? "jet2Invuln" : "jet1Invuln"]) return false;
  if (mineCooldown(state, player) > 0) return false;

  let ownedMines = 0;
  const mines = Array.isArray(state.mines) ? state.mines : [];
  for (const mine of mines) {
    if (mine.active && mine.owner === player) ownedMines++;
  }
  if (ownedMines >= MAX_MINES_PER_PLAYER) return false;

  // The mine drifts straight down from ahead of this jet's nose: it is worth
  // dropping when the rival flies close to this lane.
  return Math.abs(actor.x - opponent.x) < config.mineX;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, y: number, kind: string}|null}
 */
export function nearestThreat(state, player = 2, config = RAID_AI_DIFFICULTIES.normal) {
  const actor = jetState(state, player);
  if (!actor) return null;

  if (state.bridgeActive && state.bridgeY < actor.y && actor.y - state.bridgeY < 95) {
    return { x: CANVAS_W / 2, y: state.bridgeY, bridge: true };
  }

  const enemies = Array.isArray(state.enemies) ? state.enemies : [];
  const mines = Array.isArray(state.mines) ? state.mines : [];
  const enemyDistance = (enemy) => {
    if (!enemy.alive || !onScreen(enemy)) return null;
    const dy = actor.y - enemy.y;
    if (dy < -15 || dy > config.threatY) return null;
    return Math.abs(actor.x - enemy.x) <= WATCH_X ? Math.max(1, dy) : null;
  };
  // A mine counts as half as far: it does not move aside on its own.
  const mineDistance = (mine) => {
    if (!mine.active || mine.owner === player) return null;
    const dy = actor.y - mine.y;
    if (dy < -25 || dy > Math.min(config.threatY, 120)) return null;
    return Math.abs(actor.x - mine.x) <= WATCH_X + 10 ? Math.max(1, dy) * 0.5 : null;
  };

  return lowest([...enemies, ...mines], (thing) =>
    enemies.includes(thing) ? enemyDistance(thing) : mineDistance(thing),
  );
}

function attackTarget(state, player, config, miss) {
  const actor = jetState(state, player);
  const enemies = Array.isArray(state.enemies) ? state.enemies : [];
  const best = lowest(enemies, (enemy) => {
    if (!enemy.alive || !onScreen(enemy)) return null;
    const dy = actor.y - enemy.y;
    // Closer than `threatY` an enemy is only something to keep clear of:
    // chasing it there leads the jet into it.
    if (dy <= config.threatY || dy > config.fireY) return null;
    return dy + Math.abs(actor.x - enemy.x) * 0.4;
  });

  if (!best) return null;
  const key = `enemy:${best.id}`;
  return {
    x: clampToSafeRiver(state, aimX(best, actor.y - best.y, config) + miss(key), best.y),
    targetSpeed: best.y > actor.y - 90 ? SPEED_MIN : config.cruise,
    kind: "attack",
    key,
  };
}

function bridgeTarget(state, player, miss) {
  const actor = jetState(state, player);
  if (!state.bridgeActive || !actor || state.bridgeY < 0) return null;
  if (state.bridgeY > actor.y || actor.y - state.bridgeY > 240) return null;

  return {
    x: clampToSafeRiver(state, riverCenterAt(state, state.bridgeY) + miss("bridge"), state.bridgeY),
    targetSpeed: state.bridgeY > actor.y - 120 ? SPEED_MIN : SPEED_BASE,
    kind: "bridge",
    key: "bridge",
  };
}

/**
 * What the AI sees: the river as it was a reaction ago, with its own jet,
 * missile and cooldowns as they are now.
 * @param {object} past
 * @param {object} now
 * @param {1|2} player
 * @returns {object}
 */
export function delayedSight(past, now, player) {
  const jet = player === 1 ? "jet1" : "jet2";
  const missile = player === 1 ? "m1" : "m2";
  const own = {};
  for (const key of OWN_FIELDS) own[`${jet}${key}`] = now[`${jet}${key}`];
  own[`${missile}Active`] = now[`${missile}Active`];
  return { ...past, ...own };
}

/**
 * Where to be to hit `enemy`, `dy` ahead: where it is, or — leading by
 * `config.lead` — where it will have sailed by the time a missile gets
 * there, the AI's own reaction included.
 * @param {{x: number, vx?: number}} enemy
 * @param {number} dy
 * @param {object} config
 * @returns {number}
 */
function aimX(enemy, dy, config) {
  if (!config.lead) return enemy.x;
  const frames = dy / (MISSILE_SPEED + SPEED_BASE) + config.reaction;
  return enemy.x + (enemy.vx || 0) * frames * config.lead;
}

/**
 * A mine's own key: its id, or — on a guest, whose snapshot carries none —
 * its owner and the line it was dropped on, which it never leaves.
 * @param {{id?: number, owner: number, x: number}} mine
 * @returns {number | string}
 */
function mineKey(mine) {
  return mine.id ?? `${mine.owner}:${Math.round(mine.x)}`;
}

/** How far an enemy may move between two looks and still be the same one. */
const SAME_ENEMY_DY = 12;
const SAME_ENEMY_DX = 8;

/**
 * The state with each enemy's sideways speed. The host's enemies carry it;
 * a guest's come from the snapshot without it, so it is read off how far
 * each one moved since `previous` — the state this returned the step before
 * — and smoothed over the steps, as the snapshot rounds every position.
 * @param {object | null} previous
 * @param {object} state
 * @returns {object}
 */
export function withEnemyMotion(previous, state) {
  const enemies = Array.isArray(state.enemies) ? state.enemies : [];
  if (enemies.every((enemy) => typeof enemy.vx === "number")) return state;

  const before = Array.isArray(previous?.enemies) ? previous.enemies : [];
  const unchanged =
    before.length === enemies.length &&
    enemies.every((enemy, i) => enemy.x === before[i].x && enemy.y === before[i].y);
  if (unchanged) {
    return { ...state, enemies: enemies.map((enemy, i) => ({ ...enemy, vx: before[i].vx })) };
  }

  return {
    ...state,
    enemies: enemies.map((enemy) => {
      const last = lowest(before, (seen) => {
        const dy = enemy.y - seen.y;
        const dx = Math.abs(enemy.x - seen.x);
        if (seen.type !== enemy.type || dy < 0 || dy > SAME_ENEMY_DY || dx > SAME_ENEMY_DX) {
          return null;
        }
        return dx + dy;
      });
      return { ...enemy, vx: smoothedSpeed(last?.vx, last ? enemy.x - last.x : 0) };
    }),
  };
}

/** A speed kept steady across rounded steps, turned at once when it bounces. */
function smoothedSpeed(previous, step) {
  if (typeof previous !== "number") return step;
  if (step !== 0 && Math.sign(step) !== Math.sign(previous)) return step;
  return previous * 0.6 + step * 0.4;
}

/**
 * The sight with only the rival mines the AI noticed: whether it notices one
 * is decided once per mine, and kept while the mine is in play.
 * @param {object} sight
 * @param {1|2} player
 * @param {ReturnType<typeof createPerThing>} noticed
 * @param {() => boolean} notices - the draw for a mine not decided yet
 * @returns {object}
 */
export function noticedMines(sight, player, noticed, notices) {
  const mines = Array.isArray(sight.mines) ? sight.mines : [];
  noticed.keep(mines.map(mineKey));
  const seen = mines.filter(
    (mine) => mine.owner === player || noticed.decide(mineKey(mine), notices),
  );
  return seen.length === mines.length ? sight : { ...sight, mines: seen };
}

/**
 * The thing `score` rates lowest, the first of equals; a thing it rates null
 * is not a candidate.
 * @template T
 * @param {T[]} things
 * @param {(thing: T) => number | null} score
 * @returns {T | null}
 */
function lowest(things, score) {
  let best = null;
  let bestScore = Infinity;
  for (const thing of things) {
    const value = score(thing);
    if (value !== null && value < bestScore) {
      best = thing;
      bestScore = value;
    }
  }
  return best;
}

/** Whether a thing has come down onto the screen, where a player sees it. */
function onScreen(thing) {
  return thing.y >= 0;
}

function jetState(state, player) {
  const prefix = player === 1 ? "jet1" : "jet2";
  return {
    x: state[`${prefix}X`],
    y: state[`${prefix}Y`],
    speed: state[`${prefix}Speed`],
    fuel: state[`${prefix}Fuel`],
    alive: state[`${prefix}Alive`],
  };
}

function jetAlive(state, player) {
  return player === 1 ? state.jet1Alive === true : state.jet2Alive === true;
}

function missileActive(state, player) {
  return player === 1 ? state.m1Active === true : state.m2Active === true;
}

function missileCooldown(state, player) {
  return player === 1 ? state.jet1MissileCooldown || 0 : state.jet2MissileCooldown || 0;
}

function mineCooldown(state, player) {
  return player === 1 ? state.jet1MineCooldown || 0 : state.jet2MineCooldown || 0;
}

function safeBankAt(state, screenY) {
  const worldY = (state.scrollY || 0) + (CANVAS_H - screenY);
  return getBankAtWorld(worldY, state.seed || 0, state.mode);
}

function riverCenterAt(state, screenY) {
  const bank = safeBankAt(state, screenY);
  return (bank.leftX + bank.rightX) / 2;
}

function clampToSafeRiver(state, x, screenY) {
  const bank = safeBankAt(state, screenY);
  return clamp(x, bank.leftX + SAFE_MARGIN, bank.rightX - SAFE_MARGIN);
}
