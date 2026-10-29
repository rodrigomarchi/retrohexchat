/**
 * The phases of a match played in rounds: a spoken countdown, the bell while
 * the fighters take their places, the round itself, a pause on its end and the
 * next round — until a side has the rounds it needs and the match ends.
 *
 * ```js
 * flow: roundsFlow({
 *   phases: PHASE,
 *   play: "FIGHTING",                                   // the phase a round is played in
 *   // countdown, spawnTicks and roundOverTicks: COUNTDOWN, 1 s and 2.5 s unless told
 *   bell: (game) => game.audio.playBellStart(),
 *   startRound: (game) => { game.gameState.roundTimer = ROUND_DURATION; },
 *   states: { FIGHTING: { enter, tick: fight } },      // the play phase, and any of the game's own
 *   nextRound: resetForNewRound,
 *   winner: (s) => (s.roundWins1 >= s.roundWins2 ? 1 : 2),
 * }),
 * ```
 *
 * The game's state carries `countdown`, `score1`, `score2`, `roundWins1` and
 * `roundWins2`; the round's step moves it to ROUND_OVER or MATCH_OVER.
 *
 * A round's step publishes itself with `publishStep`, ends the round with
 * `endRoundStep` — or, for a timed round, `closeRoundStep`, which also ticks
 * the clock aloud in its last seconds; `roundsEnding(PHASE)` is the guest's end and the
 * disconnect's result for such a match.
 *
 * @module games/core/rounds
 */

import { drawOnDisconnect, guestEnd, playOutcome } from "./result.js";

/** The countdown every match starts with: from three, a number a second (60 ticks). */
export const COUNTDOWN = Object.freeze({ from: 3, every: 60 });

const SPAWN_TICKS = 60; // 1 s
const ROUND_OVER_TICKS = 150; // 2.5 s
const CLOCK_TICK_FROM = 900; // the last 15 s

/** Say a number of the countdown: on the wire, on screen and aloud. */
function say(game, remaining) {
  game.gameState.countdown = remaining;
  game.broadcast();
  game.invalidate();
  game.audio.playCountdown();
}

/**
 * A spoken countdown: `from` on entering, then one number less every
 * `every` ticks, then `next` once it reaches zero. The game's state carries
 * `countdown` and its sounds a `countdown`. With `capture`, entering it also
 * takes the keyboard for the match, before the first number is sent.
 * @param {{ from?: number, every?: number, next: string, capture?: boolean }} options -
 *   `from` and `every` are COUNTDOWN's unless told
 * @returns {object} a flow state for defineGame
 */
export function countdownState({
  from = COUNTDOWN.from,
  every = COUNTDOWN.every,
  next,
  capture = false,
}) {
  return {
    enter: capture
      ? (game) => {
          game.gameState.countdown = from;
          game.setKeyboardCaptured(true);
          game.broadcast();
          game.audio.playCountdown();
        }
      : (game) => say(game, from),
    every: { ticks: every, count: from },
    onEvery: (game, remaining) => {
      if (remaining > 0) say(game, remaining);
    },
    next,
  };
}

/**
 * A countdown that beeps as each second passes, the last one included: it
 * shows `from` on entering, then one number less every `every` ticks, and at
 * zero calls `start` instead — which begins the play `next` names. With
 * `capture`, entering it also takes the keyboard for the match.
 * @param {{ from?: number, every?: number, next: string, start: (game: object) => void, capture?: boolean }} options -
 *   `from` and `every` are COUNTDOWN's unless told
 * @returns {object} a flow state for defineGame
 */
export function beepCountdownState({
  from = COUNTDOWN.from,
  every = COUNTDOWN.every,
  next,
  start,
  capture = false,
}) {
  const show = (game, value) => {
    game.gameState.countdown = value;
    game.broadcast();
    game.invalidate();
  };
  return {
    enter: (game) => {
      game.gameState.countdown = from;
      if (capture) game.setKeyboardCaptured(true);
      game.broadcast();
      game.invalidate();
    },
    every: { ticks: every, count: from },
    onEvery: (game, remaining) => {
      game.audio.playCountdown();
      if (remaining === 0) start(game);
      else show(game, remaining);
    },
    next,
  };
}

/**
 * The round wins after a round: one more for its winner (none for 0, a
 * draw), and whether a side now has the `roundsToWin` the match needs.
 * @param {{ roundWins1: number, roundWins2: number }} state
 * @param {number} roundWinner - 1, 2, or 0 for a draw
 * @param {number} roundsToWin
 * @returns {{ roundWins1: number, roundWins2: number, matchOver: boolean }}
 */
export function tallyRound(state, roundWinner, roundsToWin) {
  const roundWins1 = state.roundWins1 + (roundWinner === 1 ? 1 : 0);
  const roundWins2 = state.roundWins2 + (roundWinner === 2 ? 1 : 0);
  const matchOver = roundWins1 >= roundsToWin || roundWins2 >= roundsToWin;
  return { roundWins1, roundWins2, matchOver };
}

/**
 * Whether a side's points reached `target`, which ends the round in its
 * favour — player one's looked at first.
 * @param {{ score1: number, score2: number }} state
 * @param {number} target
 * @returns {{ ended: boolean, roundWinner: number }}
 */
export function pointsReached(state, target) {
  if (state.score1 >= target) return { ended: true, roundWinner: 1 };
  if (state.score2 >= target) return { ended: true, roundWinner: 2 };
  return { ended: false, roundWinner: 0 };
}

/**
 * The state a round leaves: its win tallied (`tallyRound`), and the phase
 * ROUND_OVER — or MATCH_OVER once a side has the `roundsToWin` it needs.
 * @param {object} state
 * @param {number} roundWinner - 1, 2, or 0 for a draw
 * @param {number} roundsToWin
 * @param {{ ROUND_OVER: number, MATCH_OVER: number }} phases - the game's PHASE
 * @returns {object}
 */
export function closeRound(state, roundWinner, roundsToWin, phases) {
  const { matchOver, ...roundWins } = tallyRound(state, roundWinner, roundsToWin);
  return { ...state, ...roundWins, phase: matchOver ? phases.MATCH_OVER : phases.ROUND_OVER };
}

/**
 * @param {object} options
 * @param {Record<string, number>} options.phases
 * @param {string} options.play - the phase a round is played in
 * @param {{ from: number, every: number }} [options.countdown] - from what, every how many ticks
 * @param {number} [options.spawnTicks] - the bell's pause before the round
 * @param {number} [options.roundOverTicks] - the pause after a round
 * @param {(game: object) => void} options.bell
 * @param {(game: object) => void} [options.startRound] - set up the round, before it is sent
 * @param {Record<string, object>} options.states - the play phase and the game's other phases
 * @param {(state: object) => object} options.nextRound
 * @param {(state: object) => number} options.winner - 1, 2, or 0 for none
 * @returns {object} a flow table for defineGame
 */
export function roundsFlow({
  phases,
  play,
  countdown: { from, every } = COUNTDOWN,
  spawnTicks = SPAWN_TICKS,
  roundOverTicks = ROUND_OVER_TICKS,
  bell,
  startRound = () => {},
  states,
  nextRound,
  winner,
}) {
  return {
    phases,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: countdownState({ from, every, next: "SPAWNING" }),
      SPAWNING: {
        enter: (game) => {
          game.broadcast();
          game.invalidate();
          bell(game);
        },
        after: { ticks: spawnTicks },
        then: (game) => {
          game.gameState.phase = phases[play];
          startRound(game);
          game.broadcast();
        },
        next: play,
      },
      ...states,
      ROUND_OVER: {
        after: { ticks: roundOverTicks },
        then: (game) => {
          game.gameState = nextRound(game.gameState);
        },
        next: "COUNTDOWN",
      },
      MATCH_OVER: {
        final: true,
        enter: (game) => {
          const s = game.gameState;
          const won = winner(s);
          if (won === 1) game.audio.playWin();
          else game.audio.playLose();
          game.invalidate();
          game.finish({
            end: {
              score1: s.score1,
              score2: s.score2,
              winner: won,
              roundWins1: s.roundWins1,
              roundWins2: s.roundWins2,
            },
            result: { score: { p1: s.roundWins1, p2: s.roundWins2 }, winner: won },
          });
        },
      },
    },
  };
}

/**
 * Publish a round's step: the particles settle, the state is kept, the frame
 * repaints and the guest hears of it.
 * @param {object} game
 * @param {object} state
 * @param {(particles: object[]) => object[]} settle - the game's particle step
 */
export function publishStep(game, state, settle) {
  game.particles = settle(game.particles);
  game.gameState = state;
  game.invalidate();
  game.frameCount++;
  game.broadcast();
}

/**
 * The step that ends a round: its state is kept and sent, unless it ended
 * the match too — whose end reports itself on entering the final phase.
 * @param {object} game
 * @param {object} state
 */
export function endRoundStep(game, state) {
  game.gameState = state;
  if (state.phase !== game.constructor.FINAL_PHASE) game.broadcast();
}

/**
 * The close of a timed round's step: the clock ticks aloud on each second of
 * its last fifteen, and a round `rules.checkRoundEnd` finds over moves on
 * with `rules.advanceRound`, plays `rules.sound` for the state it leaves and
 * ends the step (`endRoundStep`).
 * @param {object} game
 * @param {object} state - the step's state, with `roundTimer`
 * @param {{
 *   checkRoundEnd: (state: object) => { ended: boolean, roundWinner: number },
 *   advanceRound: (state: object, roundWinner: number) => object,
 *   sound: (state: object) => void,
 * }} rules
 * @returns {boolean} whether the round ended, and with it the step
 */
export function closeRoundStep(game, state, { checkRoundEnd, advanceRound, sound }) {
  const timer = state.roundTimer;
  if (timer <= CLOCK_TICK_FROM && timer > 0 && timer % 60 === 0) game.audio.playTimerTick();

  const { ended, roundWinner } = checkRoundEnd(state);
  if (!ended) return false;
  const next = advanceRound(state, roundWinner);
  sound(next);
  endRoundStep(game, next);
  return true;
}

/**
 * The guest's end of a match played in rounds and the result a dropped
 * channel leaves: both read the rounds each side took.
 * @param {Record<string, number>} phases - the game's PHASE, with MATCH_OVER
 * @returns {{ onEnd: Function, disconnectResult: Function }} for defineGame
 */
export function roundsEnding(phases) {
  return {
    onEnd: guestEnd({
      phase: phases.MATCH_OVER,
      fields: ["roundWins1", "roundWins2"],
      sound: (game, result) => playOutcome(game, result.winner),
    }),
    disconnectResult: drawOnDisconnect((s) => [s.roundWins1, s.roundWins2]),
  };
}
