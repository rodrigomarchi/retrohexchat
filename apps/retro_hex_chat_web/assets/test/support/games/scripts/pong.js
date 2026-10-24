import { alternate } from "./keys.js";

/**
 * Both paddles sweep up and down at different rhythms after the countdown, so
 * rallies happen and points are scored on both sides.
 */
export function pongScript(side) {
  return side === "host"
    ? alternate(["ArrowUp", "ArrowDown"], { from: 4000, until: 88_000, each: 700, gap: 150 })
    : alternate(["w", "s"], { from: 4300, until: 88_000, each: 450, gap: 300 });
}
