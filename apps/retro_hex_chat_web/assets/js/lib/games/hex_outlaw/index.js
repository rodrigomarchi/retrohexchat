/**
 * Hex Outlaw: two gunslingers across a frontier street, a hit wins the
 * round, best of the rounds takes the match.
 *
 * Host-authoritative. A hit that does not end the round freezes the street
 * for a moment (HIT_PAUSE), entered and left by the simulation itself. The
 * match lifecycle comes from `defineGame`; this file says only what is
 * Outlaw's.
 *
 * @module games/hex_outlaw
 */

import { defineGame } from "../core/define_game.js";
import { createOutlawAI, normalizeOutlawAIDifficulty } from "./ai.js";
import {
  advanceRound,
  checkBulletCollisions,
  checkRoundEnd,
  createInitialState,
  enterHitPause,
  fireBullet,
  moveGunslinger,
  resetForNewRound,
  tickBullets,
  tickHitPause,
  tickObstacle,
} from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { createHitParticles, getColors, render, updateParticles } from "./renderer.js";
import { SOUNDS } from "./sounds.js";

const ROUND_OVER_DELAY_TICKS = 150; // 2.5 s
const SPAWNING_DELAY_TICKS = 60; // 1 s
const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_TICKS = 60; // 1 s

const MODE_MAP = {
  hex_outlaw_ricochet: GAME_MODE.RICOCHET,
  hex_outlaw_stagecoach: GAME_MODE.STAGECOACH,
  hex_outlaw_nml: GAME_MODE.NO_MANS_LAND,
};

/** Up aims the next shot high, down aims it level; the last one pressed holds. */
function aimRemote(game) {
  if (game.remoteInputs.up) game.remoteAimUp = true;
  if (game.remoteInputs.down) game.remoteAimUp = false;
}

/** Publish a step's state: particles settle, the frame repaints, the guest hears of it. */
function publish(game, s) {
  game.particles = updateParticles(game.particles);
  game.gameState = s;
  game.invalidate();
  game.frameCount++;
  game.broadcast();
}

function addHitParticles(game, x, y) {
  game.particles = [...game.particles, ...createHitParticles(x, y, game.fxRandom)];
}

function duel(game) {
  let s = { ...game.gameState, lastHitPlayer: 0 };

  if (s.phase === PHASE.HIT_PAUSE) {
    publish(game, tickObstacle(tickHitPause(s)));
    return;
  }

  game.updateOpponent();
  // In solo play the AI's aim counts for this step's shot.
  if (game.mode === "solo") aimRemote(game);

  const local = game.localInputs;
  const remote = game.remoteInputs;
  const p1dy = (local.down ? 1 : 0) - (local.up ? 1 : 0);
  const p1dx = (local.right ? 1 : 0) - (local.left ? 1 : 0);
  if (p1dy !== 0 || p1dx !== 0) s = moveGunslinger(s, 1, p1dy, p1dx);
  const p2dy = (remote.down ? 1 : 0) - (remote.up ? 1 : 0);
  const p2dx = (remote.right ? 1 : 0) - (remote.left ? 1 : 0);
  if (p2dy !== 0 || p2dx !== 0) s = moveGunslinger(s, 2, p2dy, p2dx);

  // A shot goes on the press, not while the key is held.
  if (local.fire && !game.localFirePressed) {
    const prev = s;
    s = fireBullet(s, 1, game.localAimUp);
    if (s !== prev) game.audio.playGunshot();
  }
  game.localFirePressed = local.fire;
  if (remote.fire && !game.remoteFirePressed) {
    const prev = s;
    s = fireBullet(s, 2, game.remoteAimUp);
    if (s !== prev) game.audio.playGunshot();
  }
  game.remoteFirePressed = remote.fire;
  aimRemote(game);

  s = tickObstacle(s);
  const prevB1Bounced = s.b1bounced;
  const prevB2Bounced = s.b2bounced;
  s = tickBullets(s);
  if (!prevB1Bounced && s.b1bounced) game.audio.playRicochet();
  if (!prevB2Bounced && s.b2bounced) game.audio.playRicochet();

  const { state: hitState, p1Hit, p2Hit, obsHit } = checkBulletCollisions(s);
  s = hitState;
  if (p1Hit || p2Hit) {
    game.audio.playHit();
    const hit = p2Hit ? "p2" : "p1";
    addHitParticles(game, s[`${hit}x`], s[`${hit}y`]);
  }
  if (obsHit) game.audio.playObstacleHit();

  if (p1Hit || p2Hit) {
    const { ended, roundWinner } = checkRoundEnd(s);
    if (ended) {
      s = advanceRound(s, roundWinner);
      game.gameState = s;
      // The match's end reports itself on entering MATCH_OVER.
      if (s.phase !== PHASE.MATCH_OVER) game.broadcast();
      return;
    }
    s = enterHitPause(s);
    game.gameState = s;
    game.broadcast();
  }

  publish(game, s);
}

function countdown(game, remaining) {
  game.gameState.countdown = remaining;
  game.broadcast();
  game.invalidate();
  game.audio.playCountdown();
}

/** The guest takes the snapshot field by field, and sees every hit. */
function applySnapshot(game, decoded) {
  Object.assign(game.gameState, decoded);
  if (decoded.lastHitPlayer !== 0) {
    const defender = decoded.lastHitPlayer === 1 ? "p2" : "p1";
    addHitParticles(game, decoded[`${defender}x`], decoded[`${defender}y`]);
  }
}

const releaseTriggers = (game) => {
  game.localFirePressed = false;
  game.remoteFirePressed = false;
};

export default defineGame({
  inputs: {
    up: ["ArrowUp", "w", "W"],
    down: ["ArrowDown", "s", "S"],
    left: ["ArrowLeft", "a", "A"],
    right: ["ArrowRight", "d", "D"],
    fire: [" ", "Shift"],
  },
  captureKeys: [
    "ArrowUp",
    "ArrowDown",
    "ArrowLeft",
    "ArrowRight",
    " ",
    "Spacebar",
    "w",
    "W",
    "a",
    "A",
    "s",
    "S",
    "d",
    "D",
  ],
  interpolate: { keys: ["p1x", "p1y", "p2x", "p2y", "b1x", "b1y", "b2x", "b2y"] },
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: { create: createOutlawAI, difficulty: normalizeOutlawAIDifficulty },
  audio: { sounds: SOUNDS },
  theme: getColors,
  // The game id picks the street: quick draw, ricochet, stagecoach or no man's land.
  init: (game) => createInitialState(MODE_MAP[game.gameId] ?? GAME_MODE.QUICK_DRAW),
  setup: (game) => {
    game.particles = [];
    releaseTriggers(game);
    game.localAimUp = false;
    game.remoteAimUp = false;
  },
  onStop: releaseTriggers,
  onBlur: releaseTriggers,
  onKeyDown: (game, event) => {
    const input = game.keyInput(event);
    if (input === "up") game.localAimUp = true;
    if (input === "down") game.localAimUp = false;
  },
  idle: (game) => {
    if (!game.particles.length) return;
    game.particles = updateParticles(game.particles);
    game.invalidate();
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: {
        enter: (game) => countdown(game, COUNTDOWN_FROM),
        every: { ticks: COUNTDOWN_EVERY_TICKS, count: COUNTDOWN_FROM },
        onEvery: (game, remaining) => {
          if (remaining > 0) countdown(game, remaining);
        },
        next: "SPAWNING",
      },
      SPAWNING: {
        enter: (game) => {
          game.broadcast();
          game.invalidate();
          game.audio.playBell();
        },
        after: { ticks: SPAWNING_DELAY_TICKS },
        // A trigger already held at the bell does not fire until pressed again.
        then: (game) => {
          game.gameState.phase = PHASE.PLAYING;
          game.broadcast();
          game.frameCount = 0;
          game.localFirePressed = game.localInputs.fire;
          game.remoteFirePressed = game.remoteInputs.fire;
        },
        next: "PLAYING",
      },
      PLAYING: { tick: duel },
      HIT_PAUSE: { tick: duel },
      ROUND_OVER: {
        after: { ticks: ROUND_OVER_DELAY_TICKS },
        then: (game) => {
          game.gameState = resetForNewRound(game.gameState);
        },
        next: "COUNTDOWN",
      },
      MATCH_OVER: {
        final: true,
        enter: (game) => {
          const s = game.gameState;
          const winner = s.roundWins1 >= s.roundWins2 ? 1 : 2;
          if (winner === 1) game.audio.playWin();
          else game.audio.playLose();
          game.invalidate();
          game.finish({
            end: {
              score1: s.score1,
              score2: s.score2,
              winner,
              roundWins1: s.roundWins1,
              roundWins2: s.roundWins2,
            },
            result: { score: { p1: s.roundWins1, p2: s.roundWins2 }, winner },
          });
        },
      },
    },
  },

  applySnapshot,
  // The guest hears every shot and hit, the countdown and the bell.
  cues: [
    { rise: (s) => s.b1active, play: "gunshot" },
    { rise: (s) => s.b2active, play: "gunshot" },
    { when: (s) => s.lastHitPlayer !== 0, play: "hit" },
    { phase: PHASE.COUNTDOWN, play: "countdown" },
    { phase: PHASE.SPAWNING, play: "bell" },
  ],
  onSnapshot: (game) => game.invalidate(),
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    Object.assign(game.gameState, {
      phase: PHASE.MATCH_OVER,
      roundWins1: result.roundWins1,
      roundWins2: result.roundWins2,
    });
    if (result.winner === 2) game.audio.playWin();
    else game.audio.playLose();
    game.invalidate();
  },
  render: (game) => {
    if (game.colors) render(game.ctx, game.gameState, game.colors, game.frameCount, game.particles);
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.roundWins1, p2: game.gameState.roundWins2 },
    winner: 0,
  }),
});
