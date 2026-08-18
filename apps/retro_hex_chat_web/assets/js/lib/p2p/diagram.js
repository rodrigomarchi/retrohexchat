/**
 * The dot maths for the P2P connection diagram — pure, no DOM.
 *
 * The heavy animation is CSS; JS only cycles dot positions along the link. The
 * diagram hook owns the requestAnimationFrame loop and the dot elements; this
 * module decides where each dot sits and how the audio mode modulates it, so
 * the three directions and the wave can be tested without a frame.
 *
 * @module p2p/diagram
 */

export const DEFAULT_DOT_COUNT = 3;
export const DEFAULT_CYCLE_MS = 1200;

/**
 * A dot's position along the link, in [0, 1].
 *
 * @param {"bidi"|"rtl"|"ltr"|string} direction
 * @param {number} progress cycle progress in [0, 1)
 * @param {number} offset the dot's phase offset
 * @returns {number}
 */
export function dotPosition(direction, progress, offset) {
  if (direction === "bidi") {
    const raw = (progress + offset) % 1;
    return raw < 0.5 ? raw * 2 : 2 - raw * 2;
  }
  if (direction === "rtl") {
    return 1 - ((progress + offset) % 1);
  }
  return (progress + offset) % 1;
}

/**
 * The inline styles for one visible dot at a moment in the cycle.
 *
 * @param {object} params
 * @param {string} params.direction
 * @param {number} params.progress cycle progress in [0, 1)
 * @param {number} params.index the dot's index
 * @param {number} params.dotCount
 * @param {boolean} params.isAudio audio mode modulates size and vertical wave
 * @returns {{left: string, opacity: string, width?: string, height?: string, top?: string}}
 */
export function dotFrame({ direction, progress, index, dotCount, isAudio }) {
  const offset = index / dotCount;
  const pos = dotPosition(direction, progress, offset);
  const frame = { left: `${pos * 100}%`, opacity: "1" };

  if (isAudio) {
    const wave = Math.sin((progress + offset) * Math.PI * 4);
    const size = 6 + wave * 3; // 3px to 9px
    frame.width = `${size}px`;
    frame.height = `${size}px`;
    frame.top = `${1 - wave * 2}px`;
  }

  return frame;
}

/**
 * The animation configuration read from the diagram element's dataset.
 *
 * `needsDots` is the reduced-motion and state gate; the caller still checks the
 * direction is not "none" before starting, as the original did.
 *
 * @param {DOMStringMap} dataset
 * @param {boolean} reducedMotion
 * @returns {{dotCount: number, cycleMs: number, state: string, direction: string, needsDots: boolean}}
 */
export function diagramConfig(dataset, reducedMotion) {
  const dotCount = parseInt(dataset.dots, 10) || DEFAULT_DOT_COUNT;
  const cycleMs = parseInt(dataset.cycleMs, 10) || DEFAULT_CYCLE_MS;
  const state = dataset.state;
  const direction = dataset.direction || "none";
  const needsDots =
    !reducedMotion &&
    (state === "transferring" || state === "video-call" || state === "audio-call");

  return { dotCount, cycleMs, state, direction, needsDots };
}
