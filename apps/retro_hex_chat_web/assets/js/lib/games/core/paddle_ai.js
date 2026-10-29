/**
 * What the AIs of the bat-and-ball games (Hex Pong, Block Breakers, Hex
 * Warlords) share: a difficulty, their random draws, a frame count, a slow
 * reaction, and one aim error per approach of the ball.
 *
 * @module games/core/paddle_ai
 */

import { TableAI, aiRequest, createApproachAim, createReaction, randomUnit } from "./ai.js";

export class PaddleAI extends TableAI {
  /**
   * @param {object} options
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   * @param {(difficulty: unknown) => string} normalize - the game's difficulty names
   * @param {Record<string, object>} table - the game's difficulty rows
   */
  constructor(options, normalize, table) {
    super(options, normalize, table);
    this.reaction = createReaction();
    this.aim = createApproachAim();
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    super.setDifficulty(difficulty);
    this.reaction.reset();
  }

  /**
   * A new round, serve or match: the next look is a fresh one, and the next
   * approach draws a fresh aim.
   * @returns {void}
   */
  forget() {
    this.reaction.reset();
    this.aim.reset();
  }

  /**
   * The common start of a frame. Outside `playing` the AI only counts the
   * frame, and null comes back. In play it takes this frame's difficulty row,
   * notes whether the ball is coming at it, and looks again at the table
   * every `config[every]` frames; what `look` saw last is the target.
   * @param {object} request - what nextInputs was asked
   * @param {number} playing - the game's PHASE.PLAYING
   * @param {object} how
   * @param {(state: object, player: 1|2) => boolean} how.incoming
   * @param {string} how.every - the row's key for frames between looks
   * @param {(state: object, player: 1|2, config: object) => number} how.look
   * @returns {{ state: object, player: 1|2, config: object, target: number }|null}
   */
  playFrame(request, playing, { incoming, every, look }) {
    const { state, player } = aiRequest(request);
    if (!state || state.phase !== playing) {
      this.frame++;
      return null;
    }

    const config = this.rowFor(request);
    this.aim.track(incoming(state, player));
    const target = this.reaction.sample(config[every], () => look(state, player, config));
    return { state, player, config, target };
  }

  /**
   * The aim error for the approach under way, drawn once within ±`errorPx`.
   * @param {number} errorPx
   * @returns {number}
   */
  aimError(errorPx) {
    return this.aim.hold(() => (randomUnit(this.rng) * 2 - 1) * errorPx || 0);
  }
}
