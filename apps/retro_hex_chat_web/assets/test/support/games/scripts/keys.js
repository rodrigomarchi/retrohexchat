/**
 * Building blocks for a pin's key script: plain data, `{ at, key, down }`.
 */

/** Hold `key` from `from` ms to `to` ms. */
export function hold(key, from, to) {
  return [
    { at: from, key, down: true },
    { at: to, key, down: false },
  ];
}

/**
 * Hold each key in turn for `each` ms, from `from` until `until`, with `gap` ms
 * of nothing between presses.
 */
export function alternate(keys, { from, until, each, gap = 0 }) {
  const presses = [];
  let at = from;
  for (let i = 0; at + each <= until; i++) {
    presses.push(...hold(keys[i % keys.length], at, at + each));
    at += each + gap;
  }
  return presses;
}

/** Press `key` briefly every `every` ms, from `from` until `until`. */
export function tap(key, { from, until, every, length = 80 }) {
  const presses = [];
  for (let at = from; at + length <= until; at += every) {
    presses.push(...hold(key, at, at + length));
  }
  return presses;
}

/**
 * A script most games share: sweep through the movement keys and tap the
 * action keys, at a rhythm that differs per side so the two players diverge.
 * The host plays on the arrows, the guest on the letters.
 * @param {"host"|"guest"} side
 * @param {{ host: string[], guest: string[] }} moves
 * @param {string[]} [actions]
 */
export function sweep(side, moves, actions = []) {
  const host = side === "host";
  const offset = host ? 0 : 300;
  return [
    ...alternate(moves[side], {
      from: 4000 + offset,
      until: 600_000,
      each: host ? 600 : 450,
      gap: 150,
    }),
    ...actions.flatMap((key, i) =>
      tap(key, { from: 4500 + offset + i * 200, until: 600_000, every: host ? 700 : 900 }),
    ),
  ];
}

export const ARROWS = {
  vertical: { host: ["ArrowUp", "ArrowDown"], guest: ["w", "s"] },
  horizontal: { host: ["ArrowLeft", "ArrowRight"], guest: ["a", "d"] },
  all: { host: ["ArrowUp", "ArrowRight", "ArrowDown", "ArrowLeft"], guest: ["w", "d", "s", "a"] },
};
