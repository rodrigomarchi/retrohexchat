/**
 * A pointer on the picture: where a mouse or a finger is, in the canvas's
 * own pixels, and whether a press is a tap or the start of a drag.
 *
 * The canvas is drawn `object-contain`: scaled to fit its element and centred,
 * with bands on the two sides the picture does not fill. A point is found by
 * undoing both, so a game reads the pixel it drew whatever size the page gave
 * it. A module of its own, so the games played with keys do not load it.
 *
 * @module games/core/pointer
 */

/**
 * The canvas pixel under a point of the page, or null off the picture.
 *
 * @param {{ left: number, top: number, width: number, height: number }} rect -
 *   the element's box (`getBoundingClientRect()`)
 * @param {number} width - the picture's width, in the game's pixels
 * @param {number} height - the picture's height
 * @param {number} clientX
 * @param {number} clientY
 * @param {{ clamp?: boolean }} [options] - `clamp: false` answers a point off
 *   the picture too, for a drag that has left it
 * @returns {{ x: number, y: number } | null}
 */
export function toCanvasPoint(rect, width, height, clientX, clientY, { clamp = true } = {}) {
  if (!(rect.width > 0 && rect.height > 0 && width > 0 && height > 0)) return null;
  const scale = Math.min(rect.width / width, rect.height / height);
  const left = rect.left + (rect.width - width * scale) / 2;
  const top = rect.top + (rect.height - height * scale) / 2;
  const x = Math.floor((clientX - left) / scale);
  const y = Math.floor((clientY - top) / scale);
  if (clamp && (x < 0 || y < 0 || x >= width || y >= height)) return null;
  return { x, y };
}

/**
 * Reads presses as taps and drags. Feed it the pointer events of one pointer
 * — `down`, `move`, `up`, `cancel`, each with `x` and `y` — and it answers
 * what they mean: `tap` (a press that moved no further than `slop`),
 * `dragStart` (at the press, once it moved further), `dragMove`, `drop`, or
 * `dragCancel`. A cancelled press that never moved means nothing.
 *
 * @param {{ slop: number }} options - how far a press may move and still be a tap
 * @returns {(event: { type: string, x?: number, y?: number }) => Array<object>}
 */
export function createGesture({ slop }) {
  let press = null;

  return (event) => {
    switch (event.type) {
      case "down":
        press = { x: event.x, y: event.y, dragging: false };
        return [];
      case "move":
        if (!press) return [];
        if (press.dragging) return [{ type: "dragMove", x: event.x, y: event.y }];
        if (Math.hypot(event.x - press.x, event.y - press.y) <= slop) return [];
        press.dragging = true;
        return [
          { type: "dragStart", x: press.x, y: press.y },
          { type: "dragMove", x: event.x, y: event.y },
        ];
      case "up": {
        if (!press) return [];
        const ended = press;
        press = null;
        return ended.dragging
          ? [{ type: "drop", x: event.x, y: event.y }]
          : [{ type: "tap", x: ended.x, y: ended.y }];
      }
      case "cancel": {
        const ended = press;
        press = null;
        return ended?.dragging ? [{ type: "dragCancel" }] : [];
      }
      default:
        return [];
    }
  };
}
