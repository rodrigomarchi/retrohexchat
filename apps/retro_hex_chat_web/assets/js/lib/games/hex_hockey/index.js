/**
 * Hex Hockey: one skater and a goalie a side, periods, sudden death or a
 * first-to-score showdown.
 *
 * Host-authoritative; the state travels packed flat. Every phase is counted
 * in steps: countdown, face-off, play, the goal celebration and the period
 * break are one simulation that moves itself on, so they share one step.
 * The match lifecycle comes from `defineGame`; this file says only what is
 * Hockey's.
 *
 * @module games/hex_hockey
 */

import { defineGame } from "../core/define_game.js";
import { playFlags } from "../core/events.js";
import { matchResult } from "../core/result.js";
import { createHockeyAI, normalizeHockeyAIDifficulty } from "./ai.js";
import {
  COUNTDOWN_FRAME_INTERVAL,
  GOAL_CELEBRATION_FRAMES,
  advancePeriod,
  checkCapture,
  checkGoal,
  checkGoalieBlock,
  checkPuckStuck,
  checkShowdownWin,
  createInitialState,
  determineWinner,
  handleShoot,
  handleTackle,
  packState,
  resetForFaceoff,
  unpackState,
  updateGoalie,
  updatePlayer,
  updatePuck,
} from "./physics.js";
import { EVENT, GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { generateIceParticles, readColors, render } from "./renderer.js";
import { MASTER_VOLUME, SOUNDS, extend } from "./sounds.js";

const FACEOFF_GO_FRAMES = 30; // how long "GO!" stays up
const COUNTDOWN_FROM = 3;

const MODE_MAP = {
  hex_hockey_blitz: GAME_MODE.BLITZ,
  hex_hockey_showdown: GAME_MODE.SHOWDOWN,
};

const RELEASED = { left: false, right: false, up: false, down: false, action: false };

/** What a goal sounds like on the guest: the horn, and the flash with it. */
function goalHeard(game) {
  game.audio.playGoal();
  game.goalFlash = GOAL_CELEBRATION_FRAMES;
}

/** The sounds both sides hear for the play's events. */
const PLAY_SOUNDS = [
  [EVENT.SHOT, "shot"],
  [EVENT.WALL_BOUNCE, "wallBounce"],
  [EVENT.GOALIE_BLOCK, "goalieBlock"],
  [EVENT.TACKLE_SUCCESS, "tackleSuccess"],
  [EVENT.TACKLE_FAIL, "tackleFail"],
  [EVENT.CAPTURE, "capture"],
];

/** The host plays the period's end and sudden death where its step makes them. */
const HOST_SOUNDS = [...PLAY_SOUNDS, [EVENT.WHISTLE, "faceoffWhistle"]];

/** The guest hears all of a step from its event bits. */
export const PEER_SOUNDS = [
  [EVENT.GOAL_P1 | EVENT.GOAL_P2, goalHeard],
  ...PLAY_SOUNDS,
  [EVENT.PERIOD_END, "periodBuzzer"],
  [EVENT.SUDDEN_DEATH, "suddenDeath"],
  [EVENT.WHISTLE, "faceoffWhistle"],
];

/** The host's sounds for a step's events; a goal's own sound has played already. */
export function playHostEvents(game, events) {
  if (events & (EVENT.GOAL_P1 | EVENT.GOAL_P2)) return;
  playFlags(game, HOST_SOUNDS, events);
}

/** The guest's sounds for a snapshot's events, the goal flash with them. */
export function playPeerEvents(game, events) {
  playFlags(game, PEER_SOUNDS, events);
}

const PLAYER_OF = { p1: 1, p2: 2 };

/** The end as the page is told it: GAME_END's `"p1"`/`"p2"`/`"draw"` as a numeric winner. */
const reported = (end) => matchResult(end.score_p1, end.score_p2, PLAYER_OF[end.winner] ?? 0);

/** The fanfare for whoever won at this screen, the falling one otherwise; either ends the drone. */
function playEnd(game, winner) {
  game.audio.stopSuddenDeath();
  if (game.outcome(PLAYER_OF[winner]) === "win") game.audio.playVictory();
  else game.audio.playLose();
}

/** A loose puck leaves a short trail; a carried one leaves none. */
export function updatePuckTrail(game) {
  if (!game.gameState) return;
  const { puck } = game.gameState;
  if (puck.possessedBy !== 0) {
    game.puckTrail = [];
    return;
  }
  game.puckTrail.push({ x: puck.x, y: puck.y });
  if (game.puckTrail.length > 8) game.puckTrail.shift();
}

/** Back to a three-beat countdown before a face-off. */
function toCountdown(game, state) {
  state.phase = PHASE.COUNTDOWN;
  state.countdownValue = COUNTDOWN_FROM;
  game.countdownFrames = COUNTDOWN_FRAME_INTERVAL;
}

/** The match ends inside the step that reaches it, before the step's snapshot. */
export function finishMatch(game, state) {
  const end = determineWinner(state);
  playEnd(game, end.winner);
  game.finish({ end, result: reported(end), broadcast: false });
}

function countdown(game, state) {
  game.countdownFrames--;
  if (game.countdownFrames > 0) return;
  state.countdownValue--;
  if (state.countdownValue <= 0) {
    state.phase = PHASE.FACE_OFF;
    state.countdownValue = 0;
    game.faceoffGoTimer = FACEOFF_GO_FRAMES;
    state.eventFlags |= EVENT.WHISTLE;
    game.audio.playGo();
  } else {
    game.countdownFrames = COUNTDOWN_FRAME_INTERVAL;
    game.audio.playCountdownTick();
  }
}

/** After "GO!", play — or sudden death once the regular periods are over. */
function faceOff(game, state) {
  game.faceoffGoTimer--;
  if (game.faceoffGoTimer > 0) return;
  const maxPeriods = state.mode === GAME_MODE.BLITZ ? 1 : 3;
  const isSudden = state.mode !== GAME_MODE.SHOWDOWN && state.period > maxPeriods;
  state.phase = isSudden ? PHASE.SUDDEN_DEATH : PHASE.PLAYING;
  if (isSudden) game.audio.playSuddenDeath();
  game.audio.playFaceoffWhistle();
}

/** After a goal: the showdown may be won, or play goes back to a countdown. */
function celebrate(game, state) {
  state.celebrationFrames--;
  game.goalFlash = state.celebrationFrames;
  if (state.celebrationFrames > 0) return;
  if (checkShowdownWin(state)) {
    state.phase = PHASE.FINISHED;
    finishMatch(game, state);
    return;
  }
  toCountdown(game, state);
  resetForFaceoff(state, null);
  game.audio.playCountdownTick();
}

function periodBreak(game, state) {
  state.periodBreakFrames--;
  if (state.periodBreakFrames > 0) return;
  toCountdown(game, state);
  resetForFaceoff(state, null);
  game.audio.playCountdownTick();
}

/** A shot when holding the puck, a tackle when not. */
function act(game, state, isP1) {
  const player = isP1 ? state.p1 : state.p2;
  return player.hasPuck ? handleShoot(state, isP1) : handleTackle(state, isP1, game.random);
}

function play(game, state) {
  game.updateOpponent();
  updatePlayer(state, game.localInputs, true);
  updatePlayer(state, game.remoteInputs, false);
  // A shot or tackle goes on the press, not while the key is held.
  if (game.localInputs.action && !game.actionHandled) {
    game.actionHandled = true;
    state.eventFlags |= act(game, state, true);
  }
  if (game.remoteInputs.action && !game.remoteActionHandled) {
    game.remoteActionHandled = true;
    state.eventFlags |= act(game, state, false);
  }

  updateGoalie(state, true);
  updateGoalie(state, false);
  state.eventFlags |= updatePuck(state);
  state.eventFlags |= checkGoalieBlock(state);
  state.eventFlags |= checkCapture(state);

  const scored = checkGoal(state);
  if (scored) {
    if (scored === "p1") {
      state.scoreP1++;
      state.eventFlags |= EVENT.GOAL_P1;
    } else {
      state.scoreP2++;
      state.eventFlags |= EVENT.GOAL_P2;
    }
    state.phase = PHASE.GOAL_CELEBRATION;
    state.celebrationFrames = GOAL_CELEBRATION_FRAMES;
    game.goalFlash = GOAL_CELEBRATION_FRAMES;
    game.audio.playGoal();
  }

  if (checkPuckStuck(state)) {
    state.eventFlags |= EVENT.FACE_OFF;
    toCountdown(game, state);
    resetForFaceoff(state, null);
    game.audio.playFaceoffWhistle();
  }

  // The period clock runs only in regular play; at zero the period ends.
  if (state.phase === PHASE.PLAYING && state.timerFrames > 0) {
    state.timerFrames--;
    if (state.timerFrames <= 0) {
      const periodEvents = advancePeriod(state);
      state.eventFlags |= periodEvents;
      if (state.phase === PHASE.PERIOD_BREAK) {
        game.audio.playPeriodBuzzer();
      } else if (periodEvents & EVENT.SUDDEN_DEATH) {
        toCountdown(game, state);
        game.audio.playPeriodBuzzer();
      } else if (state.phase === PHASE.FINISHED) {
        finishMatch(game, state);
      }
    }
  }

  updatePuckTrail(game);
  playHostEvents(game, state.eventFlags);
}

const PHASE_STEP = {
  [PHASE.COUNTDOWN]: countdown,
  [PHASE.FACE_OFF]: faceOff,
  [PHASE.GOAL_CELEBRATION]: celebrate,
  [PHASE.PERIOD_BREAK]: periodBreak,
  [PHASE.PLAYING]: play,
  [PHASE.SUDDEN_DEATH]: play,
};

function step(game) {
  if (!game.isHost || !game.gameState) return;
  game.frameCount++;
  const state = game.gameState;
  state.eventFlags = 0;
  state.frameCount = game.frameCount;

  const phaseStep = PHASE_STEP[state.phase];
  if (phaseStep) phaseStep(game, state);
  game.invalidate();
  if (phaseStep) game.broadcast();
}

/** Every step, whatever the phase, the goal flash fades. */
function tick(game) {
  step(game);
  if (game.goalFlash > 0) game.goalFlash--;
}

export default defineGame({
  inputs: {
    left: ["ArrowLeft", "a", "A"],
    right: ["ArrowRight", "d", "D"],
    up: ["ArrowUp", "w", "W"],
    down: ["ArrowDown", "s", "S"],
    action: [" ", "Spacebar", "Shift"],
  },
  captureKeys: [
    "ArrowUp",
    "ArrowDown",
    "ArrowLeft",
    "ArrowRight",
    " ",
    "Spacebar",
    "Shift",
    "w",
    "W",
    "a",
    "A",
    "s",
    "S",
    "d",
    "D",
  ],
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: { create: createHockeyAI, difficulty: normalizeHockeyAIDifficulty },
  audio: { sounds: SOUNDS, masterVolume: MASTER_VOLUME, extend },
  theme: readColors,
  // There is no rink until the engine starts.
  init: (game) => {
    game.gameMode = MODE_MAP[game.gameId] ?? GAME_MODE.CLASSIC;
    return null;
  },
  setup: (game) => {
    game.countdownFrames = 0;
    game.faceoffGoTimer = 0;
    game.actionHandled = false;
    game.remoteActionHandled = false;
    game.iceParticles = null;
    game.puckTrail = [];
    game.goalFlash = 0;
  },
  onStart: (game) => {
    game.iceParticles = generateIceParticles(40);
    if (game.isHost) game.gameState = createInitialState(game.gameMode);
  },
  onStop: (game) => {
    game.localInputs = { ...RELEASED };
    game.remoteInputs = { ...RELEASED };
    game.peerReady = false;
    game.frameCount = 0;
    game.countdownFrames = 0;
    game.faceoffGoTimer = 0;
    game.puckTrail = [];
    game.goalFlash = 0;
  },
  onAbandon: (game) => game.audio.stopSuddenDeath(),
  onKeyDown: (game, event) => {
    if (game._keyInput(event) === "action") game.actionHandled = false;
  },
  // A fresh press of the guest's (or the AI's) action always counts.
  onRemoteInputChange: (game, previous, current) => {
    if (current.action && !previous.action) game.remoteActionHandled = false;
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "STARTING",
    states: {
      // The first countdown starts the steps; later ones come from inside the step.
      STARTING: {
        as: "COUNTDOWN",
        enter: (game) => {
          const state = game.gameState;
          state.countdownValue = COUNTDOWN_FROM;
          game.countdownFrames = COUNTDOWN_FRAME_INTERVAL;
          resetForFaceoff(state, null);
          game.audio.playCountdownTick();
          game.broadcast();
        },
        tick,
      },
      COUNTDOWN: { tick },
      FACE_OFF: { tick },
      PLAYING: { tick },
      SUDDEN_DEATH: { tick },
      GOAL_CELEBRATION: { tick },
      PERIOD_BREAK: { tick },
      FINISHED: { final: true },
    },
  },

  toWire: (game) => packState(game.gameState),
  applySnapshot: (game, decoded) => {
    game.gameState = unpackState(decoded);
    updatePuckTrail(game);
  },
  cues: [{ flags: (s) => s.eventFlags, sounds: PEER_SOUNDS }],
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    playEnd(game, result.winner);
  },
  render: (game) => {
    render(game.ctx, game.gameState, game.colors, game.frameCount, {
      iceParticles: game.iceParticles,
      puckTrail: game.puckTrail,
      goalFlash: game.goalFlash,
    });
  },
  disconnectResult: (game) => matchResult(game.gameState.scoreP1, game.gameState.scoreP2, 0),
});
