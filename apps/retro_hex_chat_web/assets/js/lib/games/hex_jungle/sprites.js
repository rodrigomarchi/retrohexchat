/**
 * Hex Jungle's pixel art, as rows of characters: each character a cell, its
 * colour named by the palette the renderer hands `drawPixelSprite`; "." is
 * left blank. One cell is one of the cartridge's pixels across and one line
 * down. The explorer wears a pith helmet; nothing here copies another game.
 *
 * @module games/hex_jungle/sprites
 */

const TOP = ["..hhhh..", ".hhhhhh.", "hhhhhhhh", "..ssss..", "..sess..", "..ssss..", "...ss..."];

const ARMS_DOWN = [".cccccc.", "cccccccc", "c.cccc.c", "s.cccc.s", "s.cccc.s", "..bbbb.."];
const ARMS_UP = ["s.cccc.s", "scccccsc", "..cccc..", "..cccc..", "..cccc..", "..bbbb.."];

/** The explorer, 8 wide and 22 tall, in each pose; facing right. */
export const EXPLORER = Object.freeze({
  stand: [
    ...TOP,
    ...ARMS_DOWN,
    "..pppp..",
    "..pppp..",
    "..p..p..",
    "..p..p..",
    "..p..p..",
    "..p..p..",
    "..p..p..",
    ".kk..kk.",
    ".kk..kk.",
  ],
  stride: [
    ...TOP,
    ...ARMS_DOWN,
    "..pppp..",
    "..pppp..",
    ".pp..pp.",
    ".p....p.",
    "p......p",
    "p......p",
    "p......p",
    "kk....kk",
    "kk....kk",
  ],
  jump: [
    ...TOP,
    ...ARMS_UP,
    "..pppp..",
    ".pppppp.",
    "pp....pp",
    "p......p",
    "kk....kk",
    "........",
    "........",
    "........",
    "........",
  ],
  climb: [
    ...TOP,
    ...ARMS_UP,
    "..pppp..",
    "..pppp..",
    "..p..p..",
    "..p..p..",
    ".pp..p..",
    ".p...p..",
    ".p...p..",
    ".kk..kk.",
    ".....kk.",
  ],
  hang: [
    ...TOP,
    ...ARMS_UP,
    "..pppp..",
    "..pppp..",
    "..pp.p..",
    "..pp.p..",
    "...p.p..",
    "...p.p..",
    "...p.p..",
    "...kkk..",
    "...kk...",
  ],
  kneel: [
    "........",
    "........",
    "........",
    "........",
    "........",
    ...TOP,
    ...ARMS_DOWN,
    "..pppp..",
    ".pp..pp.",
    "kkk..kkk",
    "........",
  ].slice(0, 22),
});

/** A log lying on the ground, 8 by 4: bark, and its cut end on the right. */
export const LOG = [".ooooooO", "oooooooO", "oooooooO", ".ooooooO"];

/** Fire, 8 by 6, in two flickers. */
export const FIRE = [
  ["...r....", "..rry...", ".rryyr..", ".ryyyrr.", "rryyyyrr", ".rrrrrr."],
  ["....r...", "...yrr..", "..ryyrr.", ".rryyyr.", "rryyyyrr", ".rrrrrr."],
];

/** A coiled snake, 8 by 6. */
export const SNAKE = ["....nn..", "...nnen.", "...nnnn.", ".nnn....", "nnnnnnn.", ".nnnnnn."];

/** A crocodile's head above the water, 8 wide: jaws shut, 4 tall; open, 6. */
export const CROCODILE = Object.freeze({
  shut: ["..g.g...", "gggggggg", "gwgwgwgg", ".gggggg."],
  open: ["ggg.....", "gwg.....", "ggg.....", "ggggggg.", "gwgwgwgg", ".gggggg."],
});

/** A scorpion, 8 by 8, facing right. */
export const SCORPION = [
  ".....xx.",
  "......x.",
  "......x.",
  ".....xx.",
  ".xxxxxx.",
  "xxxxxxxe",
  ".x.x.x.x",
  "x.x.x.x.",
];

/** The treasures, 8 by 8, each in its own colours. */
export const TREASURES = Object.freeze({
  money: [
    "...tt...",
    "..t..t..",
    "...tt...",
    "..tttt..",
    ".tt$ttt.",
    ".tt$ttt.",
    ".tttttt.",
    "..tttt..",
  ],
  silver: [
    "........",
    "........",
    "........",
    "..tttt..",
    ".tttttt.",
    "tttTtttt",
    "tttttttt",
    "........",
  ],
  gold: [
    "........",
    "........",
    "........",
    "..tttt..",
    ".tttttt.",
    "tttTtttt",
    "tttttttt",
    "........",
  ],
  ring: [
    "...dd...",
    "..dDDd..",
    "...dd...",
    "..tttt..",
    ".t....t.",
    ".t....t.",
    ".t....t.",
    "..tttt..",
  ],
});
