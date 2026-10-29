/**
 * What the scripted duel players share in the AI calibration — Pixel Tanks,
 * Star Duel, Hex Outlaw and Hex Boxing: a person rethinks only every so
 * often, misjudges by a bell curve, and fires (or punches) no faster than
 * their hand allows; and the match of rounds the duels with rounds play.
 */

/**
 * A draw from the standard bell curve (Box–Muller).
 * @param {() => number} random
 * @returns {number}
 */
export function gaussian(random) {
  return Math.sqrt(-2 * Math.log(1 - random())) * Math.cos(2 * Math.PI * random());
}

/**
 * A plan made afresh every `every` frames (and on the first), kept in
 * between. `tick` counts a frame and is called once every frame, whether or
 * not the player looks.
 * @param {number} every
 * @returns {{ tick: () => number, plan: <T>(make: () => T) => T }}
 */
export function createLookout(every) {
  let frame = 0;
  let plan = null;
  return {
    tick() {
      frame++;
      return frame;
    },
    plan(make) {
      if (plan === null || frame % every === 0) plan = make();
      return plan;
    },
  };
}

/**
 * At most one shot every `every` frames. `tick` is called once every frame,
 * before asking whether the hand is `ready`.
 * @param {number} every
 * @returns {{ tick: () => void, ready: () => boolean, spend: () => void }}
 */
export function createPace(every) {
  let wait = 0;
  return {
    tick() {
      if (wait > 0) wait--;
    },
    ready: () => wait === 0,
    spend() {
      wait = every;
    },
  };
}

/**
 * A match of rounds played on the host's own step, the way the duels with
 * rounds — Pixel Tanks and Hex Boxing — run one: frame after frame until a
 * round ends, the round scored, a break in which the keys are let go and the
 * AI forgets the round (as the engine has it do), and the next round from
 * its starting places, until the match is over.
 * @param {object} start - the first round, already in play
 * @param {object} match
 * @param {(state: object, pressed: object) => { state: object, pressed: object, paused?: boolean }} match.frame -
 *   one frame, handed the keys held at the last one; a paused frame (the tanks
 *   holding still after a hit) never ends a round
 * @param {{ forget: () => void }} match.ai
 * @param {{ checkRoundEnd: Function, advanceRound: Function, resetForNewRound: Function }} match.rules -
 *   the game's own round functions
 * @param {{ play: number, over: number }} match.phases - the phase a round is
 *   played in, and the one the match ends in
 * @returns {object} the state the match ended in
 */
export function playRounds(start, { frame, ai, rules, phases }) {
  const released = () => ({ 1: false, 2: false });
  let state = start;
  let pressed = released();
  while (state.phase !== phases.over) {
    const step = frame(state, pressed);
    state = step.state;
    pressed = step.pressed;
    if (step.paused) continue;

    const { ended, roundWinner } = rules.checkRoundEnd(state);
    if (!ended) continue;
    state = rules.advanceRound(state, roundWinner);
    if (state.phase === phases.over) break;
    ai.forget();
    pressed = released();
    state = { ...rules.resetForNewRound(state), phase: phases.play };
  }
  return state;
}
