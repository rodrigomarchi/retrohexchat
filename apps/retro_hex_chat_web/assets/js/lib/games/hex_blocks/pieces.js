/**
 * Hex Blocks' pieces: every shape of four hexagons that touch — the seven
 * of them, and the mirror of the three that have a hand, ten in all — each
 * turning about a hexagon of its own, and the queue they come in, a bag of
 * the ten shuffled each time it runs out.
 *
 * @module games/hex_blocks/pieces
 */

import { shuffle } from "../core/cards.js";
import { turn } from "./hex.js";

/** A shape reflected, a left hand into a right: axial `[q, r]` into `[r, q]`. */
const mirror = (cells) => cells.map(([q, r]) => [r, q]);

/** How tall a shape stands, in half hexagons: its flattest way round comes in first. */
const height = (cells) => {
  const ys = cells.map(([q, r]) => 2 * r + q);
  return Math.max(...ys) - Math.min(...ys);
};

/** A shape turned to its flattest way round, the first of those. */
function flattest(cells) {
  let best = cells;
  for (let t = 1; t < 6; t++) {
    const turned = cells.map((c) => turn(c, t));
    if (height(turned) < height(best)) best = turned;
  }
  return best;
}

const BASE = [
  [
    "bar",
    "red",
    [
      [-1, 0],
      [0, 0],
      [1, 0],
      [2, 0],
    ],
  ],
  [
    "bee",
    "orange",
    [
      [0, 0],
      [1, 0],
      [1, -1],
      [0, -1],
    ],
  ],
  [
    "propeller",
    "yellow",
    [
      [0, 0],
      [1, 0],
      [0, -1],
      [-1, 1],
    ],
  ],
  [
    "arch",
    "lime",
    [
      [-1, -1],
      [-1, 0],
      [0, 0],
      [1, -1],
    ],
  ],
  [
    "hook",
    "green",
    [
      [-1, 0],
      [0, 0],
      [1, 0],
      [-1, -1],
    ],
  ],
  [
    "pistol",
    "teal",
    [
      [0, 0],
      [1, 0],
      [1, -1],
      [-1, 0],
    ],
  ],
  [
    "worm",
    "cyan",
    [
      [0, -1],
      [0, 0],
      [1, 0],
      [1, 1],
    ],
  ],
];
const MIRRORED = [
  ["hook_mirror", "blue", "hook"],
  ["pistol_mirror", "violet", "pistol"],
  ["worm_mirror", "pink", "worm"],
];

/** The ten pieces, by kind: a name, the colour of its art, and its hexagons about `[0, 0]`. */
export const PIECES = Object.freeze(
  [
    ...BASE,
    ...MIRRORED.map(([name, colour, of]) => [
      name,
      colour,
      mirror(BASE.find(([n]) => n === of)[2]),
    ]),
  ].map(([name, colour, cells]) => Object.freeze({ name, colour, cells: flattest(cells) })),
);

const SHAPES = PIECES.map((piece) =>
  Array.from({ length: 6 }, (_, t) => piece.cells.map((c) => turn(c, t))),
);

/** A piece's hexagons about its own, turned `times` sixths clockwise. */
export const shape = (kind, times) => SHAPES[kind][((times % 6) + 6) % 6];

const KINDS = PIECES.map((_, kind) => kind);

/** The queue topped up to at least `length` pieces, a shuffled bag of the ten at a time. */
export function fillQueue(queue, random, length) {
  let filled = queue;
  while (filled.length < length) filled = [...filled, ...shuffle(KINDS, random)];
  return filled;
}
