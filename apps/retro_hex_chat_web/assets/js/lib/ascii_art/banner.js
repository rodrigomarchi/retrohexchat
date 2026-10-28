/**
 * Text drawn as a banner in the block font: each letter's ink becomes
 * characters of a style, the words wrapped onto as many banners as the block
 * holds, and each banner coloured by a scheme.
 *
 * @module ascii_art/banner
 */
import { MAX_COLUMNS, MAX_LINES, cell } from "./cells.js";
import { HEIGHT, glyph } from "./font.js";

/** The styles a banner is drawn in. */
export const STYLES = Object.freeze(["block", "hash", "shadow"]);

/** The colour schemes: one colour, the colour on a background, a rainbow, top to bottom. */
export const SCHEMES = Object.freeze(["single", "background", "rainbow", "gradient"]);

// The rainbow's colours, left to right: red, orange, yellow, lime, cyan, royal blue, magenta.
const RAINBOW = [4, 7, 8, 9, 11, 12, 13];
// From a colour to its darker neighbour, for the rows of a gradient.
const DARKER = { 4: 5, 7: 5, 8: 7, 9: 3, 11: 10, 12: 2, 13: 6, 0: 15, 15: 14, 14: 1 };

/** A line of text as ink: `HEIGHT` rows of booleans, a column of paper between letters. */
export function ink(text) {
  const rows = Array.from({ length: HEIGHT }, () => []);
  [...text].forEach((char, i) => {
    const g = glyph(char);
    g.forEach((row, r) => {
      if (i > 0) rows[r].push(false);
      rows[r].push(...row);
    });
  });
  return rows;
}

/**
 * Ink two characters wide a pixel: a character is about twice as tall as it
 * is wide, so a pixel drawn as two is square, the way IRC banners are drawn.
 */
export const widen = (rows) => rows.map((row) => row.flatMap((cell) => [cell, cell]));

/** The words of `text` on lines whose banners are at most `columns` wide. */
export function wrap(text, columns = MAX_COLUMNS) {
  const lines = [];
  for (const paragraph of String(text).split(/\r?\n/)) {
    let line = "";
    for (const word of paragraph.split(/\s+/).filter(Boolean)) {
      const tried = line ? `${line} ${word}` : word;
      if (line && ink(tried)[0].length * 2 > columns) {
        lines.push(line);
        line = word;
      } else {
        line = tried;
      }
    }
    if (line) lines.push(line);
  }
  return lines;
}

function styled(rows, style) {
  const at = (r, c) => rows[r]?.[c] === true;
  const wide = rows[0].length + (style === "shadow" ? 1 : 0);
  const tall = rows.length + (style === "shadow" ? 1 : 0);
  return Array.from({ length: tall }, (_, r) =>
    Array.from({ length: wide }, (_, c) => {
      if (at(r, c)) return { ch: style === "hash" ? "#" : "█", ink: true };
      // The shadow falls down and to the right of the ink.
      if (style === "shadow" && at(r - 1, c - 1)) return { ch: "░", ink: false, shade: true };
      return { ch: " ", ink: false };
    }),
  );
}

function coloured(rows, { scheme, fg, bg }) {
  return rows.map((row, r) =>
    row.map((c, col) => {
      if (c.shade) return cell(c.ch, 14, scheme === "background" ? bg : null);
      if (!c.ink) return cell(c.ch, null, scheme === "background" ? bg : null);
      switch (scheme) {
        case "rainbow":
          return cell(c.ch, RAINBOW[Math.floor(col / 3) % RAINBOW.length]);
        case "gradient":
          return cell(c.ch, r < rows.length / 2 ? fg : (DARKER[fg] ?? fg));
        case "background":
          return cell(c.ch, fg, bg);
        default:
          return cell(c.ch, fg);
      }
    }),
  );
}

/**
 * The banner of `text`: its lines one under the other, a blank row between,
 * cut at what one message holds.
 * @param {string} text
 * @param {{ style?: string, scheme?: string, fg?: number, bg?: number }} [options]
 */
export function banner(text, { style = "block", scheme = "single", fg = 4, bg = 1 } = {}) {
  const out = [];
  for (const line of wrap(text, MAX_COLUMNS - 1)) {
    const rows = coloured(styled(widen(ink(line)), style), { scheme, fg, bg });
    if (out.length) out.push([]);
    out.push(...rows);
  }
  return out.slice(0, MAX_LINES).map((row) => row.slice(0, MAX_COLUMNS));
}
