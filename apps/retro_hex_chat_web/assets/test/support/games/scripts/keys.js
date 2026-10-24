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
