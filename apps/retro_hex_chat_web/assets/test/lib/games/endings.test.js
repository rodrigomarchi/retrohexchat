import { describe, it, expect, afterEach, vi } from "vitest";
import { PHASE as BREAKOUT } from "../../../js/lib/games/breakout/protocol.js";
import { PHASE as BOXING } from "../../../js/lib/games/hex_boxing/protocol.js";
import { PHASE as ENDURO } from "../../../js/lib/games/hex_enduro/protocol.js";
import { PHASE as FROST } from "../../../js/lib/games/hex_frost/protocol.js";
import {
  GOAL_BOTTOM,
  GOAL_LINE_LEFT,
  GOAL_TOP,
  PUCK_R,
} from "../../../js/lib/games/hex_hockey/physics.js";
import { PHASE as HOCKEY } from "../../../js/lib/games/hex_hockey/protocol.js";
import { PHASE as INVADERS } from "../../../js/lib/games/hex_invaders/protocol.js";
import { SCORE_TO_WIN } from "../../../js/lib/games/hex_outlaw/physics.js";
import { PHASE as OUTLAW } from "../../../js/lib/games/hex_outlaw/protocol.js";
import { PHASE as RAID } from "../../../js/lib/games/hex_raid/protocol.js";
import { PHASE as TENNIS } from "../../../js/lib/games/hex_tennis/protocol.js";
import { GRID_COLS, GRID_ROWS, WALL_SIZE } from "../../../js/lib/games/pixel_tanks/physics.js";
import { PHASE as TANKS } from "../../../js/lib/games/pixel_tanks/protocol.js";
import { PHASE as STAR_DUEL } from "../../../js/lib/games/star_duel/protocol.js";
import { PHASE as TRAILS, WINS_NEEDED } from "../../../js/lib/games/surround/protocol.js";
import { PHASE as WARLORDS } from "../../../js/lib/games/warlords/protocol.js";
import { playMatch } from "../../support/games/harness.js";

/*
 * How matches turn and end, seen from outside: a match is played through the
 * harness until it is under way, the host's state is brought to the moment in
 * question, and the test watches what both players are shown, hear and are
 * told. The timed and played-to-the-end pins rarely reach these moments — a
 * round decided on points, the player beating the AI, a goal for the guest.
 */

let match = null;

afterEach(() => {
  match?.stop();
  match?.restore();
  match = null;
});

/**
 * A match of `gameId` once the host is in `phase`. Both sides share a match
 * seed unless `matchSeed` is null: then each draws its own, as two browsers do.
 */
async function underway(gameId, phase, { mode = "p2p", matchSeed = 5 } = {}) {
  match = await playMatch({ gameId, mode, seed: 2, ...(matchSeed === null ? {} : { matchSeed }) });
  const reached = match.runUntil(() => match.engines.host.gameState?.phase === phase, 30_000);
  expect(reached, `${gameId} reaches phase ${phase}`).toBe(true);
  return match;
}

/** Change the host's state where the next step will see it. */
function set(fields) {
  Object.assign(match.engines.host.gameState, fields);
}

/** The key a game binds to an input, from its keymap. */
function keyFor(input) {
  const keymap = match.engines.host.constructor.KEYMAP;
  const key = Object.keys(keymap).find((k) => keymap[k] === input);
  expect(key, `a key for ${input}`).toBeDefined();
  return key;
}

function tap(side, input) {
  match.key(side, keyFor(input), "keydown");
  match.advance(50);
  match.key(side, keyFor(input), "keyup");
}

function spy(side, ...sounds) {
  const audio = match.engines[side].audio;
  return Object.fromEntries(sounds.map((name) => [name, vi.spyOn(audio, name)]));
}

const endOf = (limit = 60_000) => {
  const ended = match.runUntil(() => match.results.host.length > 0, limit);
  expect(ended, "the match ends").toBe(true);
  return match.results;
};

describe("Boxing", () => {
  it("counts down its last fifteen seconds aloud", async () => {
    await underway("hex_boxing", BOXING.FIGHTING);
    const { playTimerTick } = spy("host", "playTimerTick");
    set({ roundTimer: 901 });
    match.advance(100);
    expect(playTimerTick).toHaveBeenCalled();
  });

  it("rings the bell on a round decided on points, and the leader takes it", async () => {
    await underway("hex_boxing", BOXING.FIGHTING);
    const { playBellEnd, playKO } = spy("host", "playBellEnd", "playKO");
    set({ roundTimer: 1, score1: 10, score2: 4 });
    match.advance(100);
    expect(playBellEnd).toHaveBeenCalled();
    expect(playKO).not.toHaveBeenCalled();
    expect(match.engines.host.gameState).toMatchObject({ phase: BOXING.ROUND_OVER, roundWins1: 1 });
  });

  it("gives the match to the host who takes the deciding round, and tells both", async () => {
    await underway("hex_boxing", BOXING.FIGHTING);
    const { playWin } = spy("host", "playWin");
    const guest = spy("guest", "playLose");
    set({ roundTimer: 1, score1: 10, score2: 4, roundWins1: 1 });
    const results = endOf();
    expect(playWin).toHaveBeenCalled();
    expect(results.host).toEqual([{ score: { p1: 2, p2: 0 }, winner: 1 }]);
    match.advance(1000);
    expect(guest.playLose).toHaveBeenCalled();
  });
});

describe("Block Breakers", () => {
  it("cheers the pair that clears the board, and reports the shared win", async () => {
    await underway("block_breakers", BREAKOUT.PLAYING);
    const { playWin } = spy("host", "playWin");
    set({ blocksRemaining: 0 });
    const results = endOf();
    expect(playWin).toHaveBeenCalled();
    expect(results.host[0].winner).toBe(0);
  });
});

describe("Enduro", () => {
  it("fires the turbo on the press", async () => {
    await underway("hex_enduro", ENDURO.RACING);
    expect(match.engines.host.gameState.p1.boost).toBe(0);
    tap("host", "turbo");
    expect(match.engines.host.gameState.p1.boost).toBeGreaterThan(0);
  });

  it("crowns the host who leads when the clock runs out", async () => {
    await underway("hex_enduro_sprint", ENDURO.RACING);
    const { playVictory } = spy("host", "playVictory");
    const { p1, p2 } = match.engines.host.gameState;
    set({ gameTimer: 1, p1: { ...p1, score: 900 }, p2: { ...p2, score: 100 } });
    const results = endOf();
    expect(playVictory).toHaveBeenCalled();
    expect(results.host[0].winner).toBe(1);
  });
});

describe("Frost", () => {
  it("jumps the host up a row on the press", async () => {
    await underway("hex_frost", FROST.BUILDING);
    const { row } = match.engines.host.gameState.p1;
    tap("host", "up");
    expect(match.engines.host.gameState.p1.jumpToRow).toBe(row === -1 ? 0 : row - 1);
  });
});

describe("Hockey", () => {
  const intoLeftGoal = () => ({
    ...match.engines.host.gameState.puck,
    x: GOAL_LINE_LEFT - PUCK_R - 4,
    y: (GOAL_TOP + GOAL_BOTTOM) / 2,
    vx: -1,
    vy: 0,
    possessedBy: 0,
  });

  it("celebrates a goal on both sides, then faces off again", async () => {
    await underway("hex_hockey", HOCKEY.PLAYING);
    const host = spy("host", "playGoal", "playCountdownTick");
    const guest = spy("guest", "playGoal");
    set({ puck: intoLeftGoal() });
    match.advance(100);
    expect(match.engines.host.gameState).toMatchObject({
      phase: HOCKEY.GOAL_CELEBRATION,
      scoreP2: 1,
    });
    expect(host.playGoal).toHaveBeenCalledTimes(1);
    match.advance(200);
    expect(guest.playGoal).toHaveBeenCalled();
    match.runUntil(() => match.engines.host.gameState.phase === HOCKEY.COUNTDOWN, 5000);
    expect(host.playCountdownTick).toHaveBeenCalled();
  });

  it("ends a showdown on the goal that reaches the target", async () => {
    await underway("hex_hockey_showdown", HOCKEY.PLAYING);
    set({ scoreP2: 4, puck: intoLeftGoal() });
    const results = endOf();
    expect(results.host[0]).toMatchObject({ winner: 2 });
  });

  it("ends the match when the last period runs out with a leader", async () => {
    await underway("hex_hockey_blitz", HOCKEY.PLAYING);
    set({ timerFrames: 1, scoreP1: 2, scoreP2: 1 });
    const results = endOf();
    expect(results.host[0]).toMatchObject({ winner: 1 });
  });
});

describe("Invaders", () => {
  it("ends after the last wave", async () => {
    await underway("hex_invaders_blitz", INVADERS.PLAYING);
    set({ wave: 5 });
    match.engines.host.gameState.aliens?.forEach((alien) => (alien.alive = false));
    const results = endOf(120_000);
    expect(results.host).toHaveLength(1);
  });
});

describe("Outlaw", () => {
  /** The host's bullet, already on the guest. */
  const bulletOnGuest = () => {
    const { p2x, p2y } = match.engines.host.gameState;
    return { b1active: true, b1x: p2x, b1y: p2y };
  };

  it("shows the guest every hit as a burst on the one hit", async () => {
    await underway("hex_outlaw", OUTLAW.PLAYING);
    expect(match.engines.guest.particles).toHaveLength(0);
    set(bulletOnGuest());
    match.advance(100);
    expect(match.engines.guest.particles.length).toBeGreaterThan(0);
  });

  it("gives the match to the host who takes the deciding round", async () => {
    await underway("hex_outlaw", OUTLAW.PLAYING);
    const { playWin } = spy("host", "playWin");
    set({ ...bulletOnGuest(), score1: SCORE_TO_WIN - 1, roundWins1: 1 });
    const results = endOf();
    expect(playWin).toHaveBeenCalled();
    expect(results.host[0].winner).toBe(1);
  });
});

describe("Raid", () => {
  it("lays the host's mine on the press", async () => {
    await underway("hex_raid", RAID.FLYING);
    const { playMineDeploy } = spy("host", "playMineDeploy");
    tap("host", "mine");
    expect(playMineDeploy).toHaveBeenCalled();
  });

  it("downs a jet that flies into the bank", async () => {
    await underway("hex_raid", RAID.FLYING);
    const lives = match.engines.host.gameState.jet1Lives;
    set({ jet1X: 1, jet1Invuln: 0 });
    match.advance(100);
    expect(match.engines.host.gameState.jet1Lives).toBeLessThan(lives);
  });

  it("gives the match to the host when the guest's last jet goes down", async () => {
    await underway("hex_raid", RAID.FLYING);
    const { playWin } = spy("host", "playWin");
    set({ jet2Lives: 0, jet2Alive: false, score1: 50, score2: 10 });
    const results = endOf();
    expect(playWin).toHaveBeenCalled();
    expect(results.host[0].winner).toBe(1);
  });
});

describe("Tennis", () => {
  it("sounds the racket when the host returns the ball", async () => {
    await underway("hex_tennis", TENNIS.SERVING, { mode: "solo" });
    tap("host", "serve");
    match.runUntil(() => match.engines.host.gameState.phase === TENNIS.RALLY, 5000);
    const { playHit } = spy("host", "playHit");
    const s = match.engines.host.gameState;
    set({ ball: { ...s.ball, x: s.p1x, y: s.p1y, vx: 0, vy: 2, height: 0.5 } });
    match.advance(50);
    expect(playHit).toHaveBeenCalled();
  });
});

describe("Tanks", () => {
  it("gives the match to the host who leads when the deciding round's clock runs out", async () => {
    await underway("pixel_tanks", TANKS.PLAYING);
    const { playWin } = spy("host", "playWin");
    set({ roundTimer: 1, score1: 3, score2: 1, roundWins1: 1 });
    const results = endOf();
    expect(playWin).toHaveBeenCalled();
    expect(results.host[0].winner).toBe(1);
  });
});

describe("Tanks — a shell meets a wall", () => {
  /** A free cell with a wall right above it and room below, away from both tanks. */
  function cellUnderAWall(game) {
    const { walls, gameState: s } = game;
    for (let row = 2; row < GRID_ROWS - 2; row++) {
      for (let col = 2; col < GRID_COLS - 2; col++) {
        const free = (r) => !walls[r * GRID_COLS + col];
        const x = col * WALL_SIZE + WALL_SIZE / 2;
        const y = row * WALL_SIZE + 2;
        const clear = [s.tank1X - x, s.tank2X - x].every((dx) => Math.abs(dx) > 80);
        if (!free(row - 1) && free(row) && free(row + 1) && clear) return { x, y };
      }
    }
    throw new Error("no cell under a wall in this maze");
  }

  it("bounces off it once, with a ping and sparks", async () => {
    await underway("pixel_tanks", TANKS.PLAYING);
    const host = match.engines.host;
    const { playRicochet } = spy("host", "playRicochet");
    const { x, y } = cellUnderAWall(host);
    set({ m1Active: true, m1X: x, m1Y: y, m1VX: 0, m1VY: -5, m1Age: 0, m1Bounced: false });

    match.advance(20);

    expect(host.gameState).toMatchObject({ m1Active: true, m1Bounced: true });
    expect(host.gameState.m1VY).toBeGreaterThan(0);
    expect(playRicochet).toHaveBeenCalledOnce();
    expect(host.particles.some((p) => p.spark)).toBe(true);
  });
});

describe("Star Duel", () => {
  it("warps both ships on their key", async () => {
    await underway("star_duel", STAR_DUEL.PLAYING);
    const { playWarp } = spy("host", "playWarp");
    tap("host", "warp");
    tap("guest", "warp");
    match.advance(100);
    expect(playWarp).toHaveBeenCalledTimes(2);
  });

  it("wrecks a ship that flies into the debris", async () => {
    await underway("debris_field", STAR_DUEL.PLAYING);
    const s = match.engines.host.gameState;
    const [rock] = s.asteroids;
    set({ ship1: { ...s.ship1, x: rock.x, y: rock.y, invulnerable: false } });
    match.advance(50);
    expect(match.engines.host.gameState.ship1.alive).toBe(false);
  });

  it("credits no one on the guest when both score at once", async () => {
    await underway("star_duel", STAR_DUEL.PLAYING);
    const s = match.engines.host.gameState;
    set({ score1: s.score1 + 1, score2: s.score2 + 1 });
    match.advance(100);
    expect(match.engines.guest.gameState.lastScorer).toBe(0);
  });
});

describe("Light Trails", () => {
  it("lets a key that turns nothing through", async () => {
    await underway("light_trails", TRAILS.PLAYING);
    expect(match.key("host", "q").defaultPrevented).toBe(false);
  });

  it("gives the match to the host whose rival crashes in the deciding round", async () => {
    await underway("light_trails", TRAILS.PLAYING);
    const { playMatchWin } = spy("host", "playMatchWin");
    // Walled in on every side, the guest's light cycle crashes on its next move.
    const { grid, p2 } = match.engines.host.gameState;
    for (const [dx, dy] of [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ]) {
      if (grid[p2.y + dy]?.[p2.x + dx] !== undefined) grid[p2.y + dy][p2.x + dx] = 1;
    }
    set({ score1: WINS_NEEDED - 1 });
    const results = endOf();
    expect(playMatchWin).toHaveBeenCalled();
    expect(results.host[0].winner).toBe(1);
  });
});

describe("Warlords", () => {
  it("shows the guest the host's king fall", async () => {
    await underway("hex_warlords", WARLORDS.PLAYING);
    set({ p1Lives: match.engines.host.gameState.p1Lives - 1, phase: WARLORDS.KING_HIT });
    match.advance(100);
    expect(match.engines.guest.gameState).toMatchObject({ kingHitPlayer: 1, p1KingAlive: false });
  });

  it("lets a caught fireball go when the host releases the key, or leaves the window", async () => {
    await underway("hex_warlords", WARLORDS.PLAYING);
    set({ caughtBy: 1 });
    match.key("host", keyFor("space"), "keyup");
    expect(match.engines.host.gameState.caughtBy).toBe(0);
    set({ caughtBy: 1 });
    window.dispatchEvent(new Event("blur"));
    expect(match.engines.host.gameState.caughtBy).toBe(0);
  });

  it("gives the match to the host when the guest's last king falls", async () => {
    await underway("hex_warlords", WARLORDS.PLAYING);
    const { playWin } = spy("host", "playWin");
    set({ p2Lives: 0, phase: WARLORDS.KING_HIT });
    const results = endOf();
    expect(playWin).toHaveBeenCalled();
    expect(results.host[0].winner).toBe(1);
  });
});
