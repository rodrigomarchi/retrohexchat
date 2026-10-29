/**
 * The one spelling a match result is reported in, for every game: a nested
 * score and a numeric winner — 1 or 2 for a side, 0 for a draw (or a co-op
 * pair's win), -1 for a co-op pair's loss. `Games.Result` on the server
 * reads it, and still reads the older spellings browsers with an older
 * chunk may send. Also here: the result a disconnect leaves, the ending
 * sound, and the guest's end of a match.
 *
 * @module games/core/result
 */

/**
 * @param {number} p1 - player one's score
 * @param {number} p2 - player two's score
 * @param {number} winner
 * @returns {{ score: { p1: number, p2: number }, winner: number }}
 */
export function matchResult(p1, p2, winner) {
  return { score: { p1, p2 }, winner };
}

/**
 * The end of a match scored as two numbers: the guest is told
 * `{ score1, score2, winner }`, and the page the same score as a result.
 * @param {object} game
 * @param {number} score1
 * @param {number} score2
 * @param {number} winner
 * @param {{ broadcast?: boolean }} [options] - `broadcast: false` leaves out
 *   the last snapshot, for a game that sent it before the end
 */
export function finishScored(game, score1, score2, winner, { broadcast = true } = {}) {
  game.finish({
    end: { score1, score2, winner },
    result: matchResult(score1, score2, winner),
    broadcast,
  });
}

/**
 * A one-player game's result: its points, and nobody beaten. The server reads
 * the same spelling as every other result, with player two on nothing.
 * @param {number} points
 * @returns {{ score: { p1: number, p2: number }, winner: number }}
 */
export function soloResult(points) {
  return matchResult(points, 0, 0);
}

/**
 * A disconnect's result: the score as it stood, and nobody the winner.
 * @param {(state: object) => [number, number]} score - p1's and p2's score from the state
 * @returns {(game: object) => { score: { p1: number, p2: number }, winner: number }}
 */
export function drawOnDisconnect(score) {
  return (game) => {
    const [p1, p2] = score(game.gameState);
    return matchResult(p1, p2, 0);
  };
}

/**
 * The ending sound for the player at this screen: `win` when the match was
 * theirs, `lose` otherwise (a draw included).
 * @param {object} game
 * @param {number} winner
 * @param {string} [win] - the sound's player name
 * @param {string} [lose]
 */
export function playOutcome(game, winner, win = "playWin", lose = "playLose") {
  if (game.outcome(winner) === "win") game.audio[win]();
  else game.audio[lose]();
}

/**
 * The guest's end of a match as most games spell it: the keyboard released,
 * the final `phase` and the result's own `fields` copied onto the state, the
 * ending `sound`, then a repaint.
 * @param {{ phase: number, fields?: string[], sound: (game: object, result: object) => void, repaint?: boolean }} options
 * @returns {(game: object, result: object) => void} an `onEnd` for defineGame
 */
export function guestEnd({ phase, fields = [], sound, repaint = true }) {
  return (game, result) => {
    game.setKeyboardCaptured(false);
    const copied = { phase };
    for (const field of fields) copied[field] = result[field];
    Object.assign(game.gameState, copied);
    sound(game, result);
    if (repaint) game.invalidate();
  };
}

/**
 * The guest's end of a race: the state, when it has one, shown finished in
 * `phase`; the keyboard released; `quiet(game)` stops what the race kept
 * playing; then the victory or the game-over sound.
 * @param {number} phase - the game's final phase
 * @param {(game: object) => void} quiet
 * @returns {(game: object, result: { winner: number }) => void} for defineGame's `onEnd`
 */
export function raceEnd(phase, quiet) {
  return (game, result) => {
    if (game.gameState) game.gameState = { ...game.gameState, phase };
    game.invalidate();
    game.setKeyboardCaptured(false);
    quiet(game);
    playOutcome(game, result.winner, "playVictory", "playGameOver");
  };
}
