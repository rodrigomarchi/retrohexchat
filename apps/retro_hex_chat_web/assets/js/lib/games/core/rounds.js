/**
 * The phases of a match played in rounds: a spoken countdown, the bell while
 * the fighters take their places, the round itself, a pause on its end and the
 * next round — until a side has the rounds it needs and the match ends.
 *
 * ```js
 * flow: roundsFlow({
 *   phases: PHASE,
 *   play: "FIGHTING",                                   // the phase a round is played in
 *   countdown: { from: 3, every: COUNTDOWN_EVERY_TICKS },
 *   spawnTicks: SPAWNING_DELAY_TICKS,
 *   roundOverTicks: ROUND_OVER_DELAY_TICKS,
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
 * @module games/core/rounds
 */

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
 * `countdown` and its sounds a `countdown`.
 * @param {{ from: number, every: number, next: string }} options
 * @returns {object} a flow state for defineGame
 */
export function countdownState({ from, every, next }) {
  return {
    enter: (game) => say(game, from),
    every: { ticks: every, count: from },
    onEvery: (game, remaining) => {
      if (remaining > 0) say(game, remaining);
    },
    next,
  };
}

/**
 * @param {object} options
 * @param {Record<string, number>} options.phases
 * @param {string} options.play - the phase a round is played in
 * @param {{ from: number, every: number }} options.countdown - from what, every how many ticks
 * @param {number} options.spawnTicks - the bell's pause before the round
 * @param {number} options.roundOverTicks - the pause after a round
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
  countdown: { from, every },
  spawnTicks,
  roundOverTicks,
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
