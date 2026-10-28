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

/** Whether `x`, `y` lands on the place `r` (`{ x, y, w, h }`); never on a place there is none of. */
export const contains = (r, x, y) =>
  Boolean(r) && x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h;

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
 * A press, read as the gesture it makes: `tap` (a press that moved no
 * further than `slop`), `dragStart` (at the press, once it moved further),
 * `dragMove`, `drop`, or `dragCancel`. A cancelled press that never moved
 * means nothing. A tap says which button made it when the press did
 * (`button`, from a game that takes the secondary button).
 *
 * With `holdTicks`, a press kept within `slop` for that many ticks is a
 * `hold` (a long press: a finger's right click), counted by `tick()` — one
 * call each tick, so a script of presses replays the same holds — and its
 * release then means nothing. A press that says `hold: false` (a mouse's,
 * whose right button flags) never holds.
 *
 * @param {{ slop: number, holdTicks?: number }} options
 * @returns {((event: { type: string, x?: number, y?: number, button?: string }) => Array<object>)
 *   & { tick: () => Array<object> }}
 */
export function createGesture({ slop, holdTicks = 0 }) {
  let press = null;

  const tapOf = (ended) =>
    ended.button === undefined
      ? { type: "tap", x: ended.x, y: ended.y }
      : { type: "tap", x: ended.x, y: ended.y, button: ended.button };

  const gesture = (event) => {
    switch (event.type) {
      case "down":
        press = {
          x: event.x,
          y: event.y,
          dragging: false,
          held: 0,
          holds: event.hold !== false,
          button: event.button,
        };
        return [];
      case "move":
        if (!press) return [];
        if (press.dragging) return [{ type: "dragMove", x: event.x, y: event.y }];
        if (Math.hypot(event.x - press.x, event.y - press.y) <= slop) return [];
        if (press.held < 0) return [];
        press.dragging = true;
        return [
          { type: "dragStart", x: press.x, y: press.y },
          { type: "dragMove", x: event.x, y: event.y },
        ];
      case "up": {
        if (!press) return [];
        const ended = press;
        press = null;
        if (ended.held < 0) return [];
        return ended.dragging ? [{ type: "drop", x: event.x, y: event.y }] : [tapOf(ended)];
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

  // A press already held is marked with a negative count: it holds once.
  gesture.tick = () => {
    if (!holdTicks || !press?.holds || press.dragging || press.held < 0) return [];
    press.held += 1;
    if (press.held < holdTicks) return [];
    press.held = -1;
    return [{ type: "hold", x: press.x, y: press.y }];
  };

  return gesture;
}
