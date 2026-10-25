/**
 * What the guest hears, declared: each cue names something a new snapshot
 * may show against the one before it, and the sound it plays. The host
 * plays its sounds where its simulation makes them; the guest only sees
 * states, so it hears them from what changed.
 *
 * ```js
 * cues: [
 *   { phase: PHASE.COUNTDOWN, play: "countdown" },               // a phase entered
 *   { change: (s) => s.score1 + s.score2, play: "score" },       // a value changed
 *   { rise: (s) => s.hitEvent, play: "hit" },                    // a flag went up
 *   { flags: (s) => s.events, sounds: [[EVENT.SHOT, "shot"]] },  // event bits it carries
 *   { when: (s, prev) => s.lives < prev.lives, play: "lifeLost" },
 * ]
 * ```
 *
 * `play` is a sound's name (`"score"` plays `playScore()`) or a function of
 * the game and both states, for a sound that needs more. Cues play in the
 * order they are declared.
 *
 * @module games/core/events
 */

const methodOf = (name) => `play${name[0].toUpperCase()}${name.slice(1)}`;

function fired(cue, current, previous) {
  if ("phase" in cue) return current.phase === cue.phase && previous.phase !== cue.phase;
  if (cue.change) return cue.change(current) !== cue.change(previous);
  if (cue.rise) return Boolean(cue.rise(current)) && !cue.rise(previous);
  if (cue.when) return cue.when(current, previous);
  return false;
}

function sound(game, play, current, previous) {
  if (typeof play === "function") play(game, current, previous);
  else game.audio[methodOf(play)]();
}

/**
 * Play the sound of every bit set in `bits`, in the table's order: the host
 * hears a step's events this way, from the same table a `flags` cue gives
 * the guest.
 * @param {{ audio: object }} game
 * @param {Array<[number, string | Function]>} sounds - bit (or bits) and the sound it plays
 * @param {number} bits
 */
export function playFlags(game, sounds, bits) {
  for (const [bit, play] of sounds) if (bits & bit) sound(game, play, null, null);
}

/**
 * Play the cues a new state fires against the previous one.
 * @param {Array<object>} cues
 * @param {object} previous - the state before the snapshot
 * @param {object} current - the state after it
 * @param {{ audio: object }} game
 */
export function cueSounds(cues, previous, current, game) {
  for (const cue of cues) {
    if (cue.flags) {
      const bits = cue.flags(current) || 0;
      for (const [bit, play] of cue.sounds) if (bits & bit) sound(game, play, current, previous);
    } else if (fired(cue, current, previous)) {
      sound(game, cue.play, current, previous);
    }
  }
}
