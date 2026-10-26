/**
 * The pieces a platform game moves its people with: a jump read from a table,
 * a fall onto a floor, a ladder's reach and its rungs, boxes that touch, and
 * the edge a walker leaves the screen by. Pure functions of plain bodies
 * (`{ x, y, … }`, y growing downwards), counted in simulation ticks; what a
 * game's world holds — its ladders, floors and hazards — it passes in. A
 * module of its own, so the games without platforms do not load it.
 * @module games/core/platform
 */

/**
 * Whether something that happens once every `every` ticks happens on `tick`.
 * @param {number} tick
 * @param {number} every
 * @returns {boolean}
 */
export function cadence(tick, every) {
  return tick % every === 0;
}

/**
 * One tick of a jump: the body moves by the table's entry for this tick (up
 * positive) and counts it. A body whose table has run out is handed back as
 * it is; the game decides what follows (a landing, a fall).
 * @param {{ y: number, jumpTick: number }} body
 * @param {number[]} table - lines moved each tick
 * @returns {object} the body after the tick
 */
export function jumpStep(body, table) {
  if (body.jumpTick >= table.length) return body;
  return { ...body, y: body.y - table[body.jumpTick], jumpTick: body.jumpTick + 1 };
}

/**
 * One tick of a fall onto a floor, never past it.
 * @param {{ y: number }} body
 * @param {number} floorY
 * @param {number} [speed] - lines a tick
 * @returns {object} the body after the tick
 */
export function fall(body, floorY, speed = 1) {
  return { ...body, y: Math.min(body.y + speed, floorY) };
}

/**
 * Where a body standing at `x` holds a ladder: on the ladder's line, when the
 * ladder is within its reach.
 * @param {number} x
 * @param {{ left: number, right: number, x: number }} ladder - the reach, inclusive, and the line
 * @returns {number|null} the x it climbs at, or null out of reach
 */
export function ladderGrab(x, ladder) {
  return x >= ladder.left && x <= ladder.right ? ladder.x : null;
}

/**
 * One tick on a ladder: a rung up or down every `every` ticks, held between
 * its top and its bottom.
 * @param {{ y: number }} body
 * @param {{ top: number, bottom: number, rung: number, every: number }} ladder
 * @param {-1|0|1} direction - up, still, down
 * @param {number} tick
 * @returns {object} the body after the tick
 */
export function climbStep(body, ladder, direction, tick) {
  if (direction === 0 || !cadence(tick, ladder.every)) return body;
  const y = Math.min(Math.max(body.y + direction * ladder.rung, ladder.top), ladder.bottom);
  return { ...body, y };
}

/**
 * Whether two boxes share a pixel; boxes that only touch do not.
 * @param {{ x: number, y: number, w: number, h: number }} a
 * @param {{ x: number, y: number, w: number, h: number }} b
 * @returns {boolean}
 */
export function overlaps(a, b) {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

/**
 * The edge a position has left the screen by.
 * @param {number} x
 * @param {number} min - the leftmost position still on the screen
 * @param {number} max - the rightmost
 * @returns {-1|0|1} left, still on it, right
 */
export function edgeExit(x, min, max) {
  if (x < min) return -1;
  if (x > max) return 1;
  return 0;
}
