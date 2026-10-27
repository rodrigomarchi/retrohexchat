/**
 * Solving a Sudoku grid two ways: by search, to count its solutions (does it
 * have exactly one?), and by technique, as a person would, to tell how hard
 * it is — the level of the hardest technique it needed.
 *
 * A technique works on the candidates (`grid.js`'s masks, 0 on a filled
 * square), takes out what it can prove, and says whether it took anything.
 *
 * @module games/hex_sudoku/solver
 */

import {
  ALL,
  PEERS,
  SQUARES,
  UNITS,
  UNITS_OF,
  bit,
  candidates,
  count,
  digitsOf,
  sees,
  solved,
  valid,
} from "./grid.js";

/** How hard each technique is: 1 the easy level's, 2 the medium's, 3 the hard's. */
export const LEVEL_OF = Object.freeze({
  nakedSingle: 1,
  hiddenSingle: 1,
  nakedSubsets: 2,
  hiddenSubsets: 2,
  pointing: 2,
  boxLine: 2,
  fish: 3,
  xyWing: 3,
});

/** Each pair, then each trio, of the numbers below `n`, as lists. */
const GROUPS = Object.freeze(
  Array.from({ length: 10 }, (_, n) => {
    const groups = [];
    for (let a = 0; a < n; a++) {
      for (let b = a + 1; b < n; b++) {
        groups.push([a, b]);
        for (let c = b + 1; c < n; c++) groups.push([a, b, c]);
      }
    }
    return Object.freeze(groups.sort((x, y) => x.length - y.length));
  }),
);

/** Takes `mask` out of the squares `from`, saying whether any had it. */
function strike(cand, from, mask) {
  let struck = false;
  for (const i of from) {
    if (cand[i] & mask) {
      cand[i] &= ~mask;
      struck = true;
    }
  }
  return struck;
}

/** The squares of `unit` at the places a mask of nine bits names. */
const placed = (unit, places) => unit.filter((_, n) => places & (1 << n));

/** Where digit `d` fits in `unit`, as a mask of the unit's nine places. */
function placesOf(cand, unit, d) {
  let places = 0;
  for (let n = 0; n < 9; n++) if (cand[unit[n]] & bit(d)) places |= 1 << n;
  return places;
}

/**
 * The grid's solutions by search, filling in `order` (digits from a mask, as
 * the caller wants them tried), each found handed to `found` until it says stop.
 */
function search(values, order, found) {
  const grid = [...values];
  const used = Array(27).fill(0);
  for (const i of SQUARES) for (const u of UNITS_OF[i]) if (grid[i]) used[u] |= bit(grid[i]);
  const free = (i) => ALL & ~UNITS_OF[i].reduce((mask, u) => mask | used[u], 0);
  const step = () => {
    // The empty square with the fewest digits left goes first.
    let best = -1;
    let bestMask = 0;
    for (const i of SQUARES) {
      if (grid[i]) continue;
      const mask = free(i);
      if (!mask) return false;
      if (best < 0 || count(mask) < count(bestMask)) {
        best = i;
        bestMask = mask;
        if (count(mask) === 1) break;
      }
    }
    if (best < 0) return found([...grid]);
    for (const d of order(bestMask)) {
      grid[best] = d;
      for (const u of UNITS_OF[best]) used[u] |= bit(d);
      const stop = step();
      for (const u of UNITS_OF[best]) used[u] &= ~bit(d);
      grid[best] = 0;
      if (stop) return true;
    }
    return false;
  };
  step();
}

/** How many solutions the grid has, counted up to `limit`: 0 for one that breaks the rules. */
export function countSolutions(values, limit = 2) {
  if (!valid(values)) return 0;
  let solutions = 0;
  search(values, digitsOf, () => ++solutions >= limit);
  return solutions;
}

/** A whole grid at random: the empty grid filled, its digits tried in an order `random` shuffles. */
export function fullGrid(random) {
  let grid = null;
  const shuffled = (mask) => {
    const digits = digitsOf(mask);
    for (let n = digits.length - 1; n > 0; n--) {
      const m = Math.floor(random() * (n + 1));
      [digits[n], digits[m]] = [digits[m], digits[n]];
    }
    return digits;
  };
  search(Array(81).fill(0), shuffled, (solution) => {
    grid = solution;
    return true;
  });
  return grid;
}

/** A square left one digit: `{ i, d }`, or null. */
function nakedSingle(cand) {
  const i = cand.findIndex((mask) => mask && !(mask & (mask - 1)));
  return i < 0 ? null : { i, d: 32 - Math.clz32(cand[i]) };
}

/** A digit with one place left in a unit: `{ i, d }`, or null. */
function hiddenSingle(cand) {
  for (const unit of UNITS) {
    let once = 0;
    let twice = 0;
    for (const i of unit) {
      twice |= once & cand[i];
      once |= cand[i];
    }
    const lone = once & ~twice;
    if (lone) {
      const d = 32 - Math.clz32(lone & -lone);
      return { i: unit.find((i) => cand[i] & bit(d)), d };
    }
  }
  return null;
}

/** Squares of a unit holding only two or three digits between them: those digits leave the rest of it. */
export function nakedSubsets(cand) {
  for (const k of [2, 3]) {
    for (const unit of UNITS) {
      const open = unit.filter((i) => cand[i] && count(cand[i]) <= k);
      for (const group of GROUPS[open.length]) {
        if (group.length !== k) continue;
        const subset = group.map((n) => open[n]);
        const mask = subset.reduce((m, i) => m | cand[i], 0);
        if (count(mask) !== k) continue;
        if (
          strike(
            cand,
            unit.filter((i) => !subset.includes(i)),
            mask,
          )
        ) {
          return true;
        }
      }
    }
  }
  return false;
}

/** Two or three digits that fit only as many squares of a unit: those squares hold nothing else. */
export function hiddenSubsets(cand) {
  for (const k of [2, 3]) {
    for (const unit of UNITS) {
      const digits = [];
      const places = [];
      for (let d = 1; d <= 9; d++) {
        const where = placesOf(cand, unit, d);
        if (where && count(where) <= k) {
          digits.push(d);
          places.push(where);
        }
      }
      for (const group of GROUPS[digits.length]) {
        if (group.length !== k) continue;
        const where = group.reduce((m, n) => m | places[n], 0);
        if (count(where) !== k) continue;
        const keep = group.reduce((m, n) => m | bit(digits[n]), 0);
        if (strike(cand, placed(unit, where), ALL & ~keep)) return true;
      }
    }
  }
  return false;
}

const ROWS = UNITS.slice(0, 9);
const COLUMNS = UNITS.slice(9, 18);
const BOXES = UNITS.slice(18);

/**
 * A digit kept, inside one unit, to the squares it shares with another
 * leaves the rest of that other unit: `crossing(unit, places)` names the
 * other unit the places all lie in, or null.
 */
function confined(cand, units, crossing) {
  for (const unit of units) {
    for (let d = 1; d <= 9; d++) {
      const where = placesOf(cand, unit, d);
      if (count(where) < 2) continue;
      for (const other of crossing(unit, where)) {
        if (
          strike(
            cand,
            other.filter((i) => !unit.includes(i)),
            bit(d),
          )
        ) {
          return true;
        }
      }
    }
  }
  return false;
}

// A box's nine places run in three rows of three: the places of each row, and of each column.
const BOX_ROWS = [0b000000111, 0b000111000, 0b111000000];
const BOX_COLUMNS = [0b001001001, 0b010010010, 0b100100100];
const within = (where, parts) => parts.findIndex((part) => !(where & ~part));

/** A digit kept to one row or column of a box leaves the rest of that line. */
export const pointing = (cand) =>
  confined(cand, BOXES, (box, where) => {
    const row = within(where, BOX_ROWS);
    const column = within(where, BOX_COLUMNS);
    return [
      ...(row < 0 ? [] : [ROWS[Math.floor(box[0] / 9) + row]]),
      ...(column < 0 ? [] : [COLUMNS[(box[0] % 9) + column]]),
    ];
  });

// A row's or column's nine places, three to each box it crosses.
const LINE_THIRDS = [0b000000111, 0b000111000, 0b111000000];

/** A digit kept to one box in a row or column leaves the rest of that box. */
export const boxLine = (cand) =>
  confined(cand, [...ROWS, ...COLUMNS], (line, where) => {
    const third = within(where, LINE_THIRDS);
    return third < 0 ? [] : [BOXES.find((box) => box.includes(line[third * 3]))];
  });

/**
 * An X-Wing (two lines) or a Swordfish (three): a digit kept, in `n` rows, to
 * the same `n` columns leaves the rest of those columns; and the same with
 * rows and columns swapped.
 */
export function fish(cand) {
  for (const n of [2, 3]) {
    for (const [lines, crosses] of [
      [ROWS, COLUMNS],
      [COLUMNS, ROWS],
    ]) {
      for (let d = 1; d <= 9; d++) {
        const base = [];
        const covers = [];
        lines.forEach((line, l) => {
          const where = placesOf(cand, line, d);
          if (count(where) >= 2 && count(where) <= n) {
            base.push(l);
            covers.push(where);
          }
        });
        for (const group of GROUPS[base.length]) {
          if (group.length !== n) continue;
          const cover = group.reduce((m, g) => m | covers[g], 0);
          if (count(cover) !== n) continue;
          const kept = group.map((g) => base[g]);
          const squares = placed(crosses, cover).flatMap((cross) =>
            cross.filter((_, l) => !kept.includes(l)),
          );
          if (strike(cand, squares, bit(d))) return true;
        }
      }
    }
  }
  return false;
}

/**
 * An XY-Wing: a square of two digits `xy` sees one of `xz` and one of `yz`;
 * whichever the first holds, one of the others is `z`, so `z` leaves every
 * square that sees both.
 */
export function xyWing(cand) {
  const pairs = SQUARES.filter((i) => count(cand[i]) === 2);
  for (const pivot of pairs) {
    const wings = pairs.filter((i) => sees(pivot, i) && count(cand[i] & cand[pivot]) === 1);
    for (let x = 0; x < wings.length; x++) {
      for (let y = x + 1; y < wings.length; y++) {
        const [a, b] = [wings[x], wings[y]];
        const z = cand[a] & ~cand[pivot];
        if (cand[b] !== ((cand[pivot] & ~cand[a]) | z)) continue;
        const both = PEERS[a].filter((i) => i !== b && sees(i, b));
        if (strike(cand, both, z)) return true;
      }
    }
  }
  return false;
}

/** The techniques that take candidates out, easiest first. */
const ELIMINATIONS = Object.freeze([
  ["pointing", pointing],
  ["boxLine", boxLine],
  ["nakedSubsets", nakedSubsets],
  ["hiddenSubsets", hiddenSubsets],
  ["fish", fish],
  ["xyWing", xyWing],
]);

/** Digit `d` put on square `i`: it leaves the square's peers. */
function place(values, cand, { i, d }) {
  values[i] = d;
  cand[i] = 0;
  for (const p of PEERS[i]) cand[p] &= ~bit(d);
}

/**
 * The grid solved as a person would, with no technique past `maxLevel`: each
 * step takes the easiest technique that does something.
 * @returns {{ solved: boolean, values: number[], level: number }} how far it
 *   got, and the level of the hardest technique it needed
 */
export function solveLogically(start, maxLevel = 3) {
  const values = [...start];
  const cand = candidates(values);
  let level = 0;
  while (values.some((v) => !v)) {
    if (values.some((v, i) => !v && !cand[i])) break;
    const single = nakedSingle(cand) ?? hiddenSingle(cand);
    if (single) {
      place(values, cand, single);
      level = Math.max(level, 1);
      continue;
    }
    const used = ELIMINATIONS.find(
      ([name, technique]) => LEVEL_OF[name] <= maxLevel && technique(cand),
    );
    if (!used) break;
    level = Math.max(level, LEVEL_OF[used[0]]);
  }
  return { solved: solved(values), values, level };
}
