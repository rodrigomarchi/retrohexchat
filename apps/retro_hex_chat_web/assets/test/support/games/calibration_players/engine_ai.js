/**
 * The AI as the engine runs it during a calibration trial: player two, at
 * the trial's difficulty. The engine watches the phase on every step, asked
 * or not, and has the AI forget its round memories whenever it changes —
 * at every new round, serve or match.
 * @param {object} ai - the game's AI controller
 * @param {string} difficulty
 * @returns {{ watch: (state: object) => void, ask: (state: object) => object }}
 *   `watch` is the engine's look at a step's state; `ask` watches it, then
 *   takes the AI's inputs for that frame
 */
export function engineAI(ai, difficulty) {
  let seenPhase;
  const watch = (state) => {
    if (state.phase === seenPhase) return;
    seenPhase = state.phase;
    ai.forget();
  };
  return {
    watch,
    ask(state) {
      watch(state);
      return ai.nextInputs({ state, player: 2, difficulty });
    },
  };
}

/**
 * The AI asked on every step, as most games ask it.
 * @param {object} ai
 * @param {string} difficulty
 * @returns {(state: object) => object} the AI's inputs for this frame
 */
export function askAsTheEngineDoes(ai, difficulty) {
  return engineAI(ai, difficulty).ask;
}
