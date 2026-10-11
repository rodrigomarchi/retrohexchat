/**
 * Lays a speech bubble's text out in lines.
 *
 * A bubble is one sentence over a character's head, so it wraps at a fixed
 * width instead of running off the edge of the map, and stops at a few lines:
 * the conversation keeps the whole message, the bubble only has to say enough
 * to be followed. A word wider than a line is broken where it overflows.
 * @module space/bubble_layout
 */

export const BUBBLE_MAX_WIDTH = 150;
export const BUBBLE_MAX_LINES = 4;
const ELLIPSIS = "…";

/**
 * @param {string} text
 * @param {(s: string) => number} measure width of a string in the bubble's font
 * @param {{maxWidth?: number, maxLines?: number}} [opts]
 * @returns {string[]} the lines to draw, top to bottom
 */
export function wrapBubbleText(text, measure, opts = {}) {
  const maxWidth = opts.maxWidth ?? BUBBLE_MAX_WIDTH;
  const maxLines = opts.maxLines ?? BUBBLE_MAX_LINES;
  const words = String(text).split(/\s+/).filter(Boolean);
  const lines = [];
  let line = "";

  for (const word of words) {
    const candidate = line ? `${line} ${word}` : word;
    if (measure(candidate) <= maxWidth) {
      line = candidate;
      continue;
    }
    if (line) lines.push(line);
    line = word;
    while (measure(line) > maxWidth && line.length > 1) {
      const cut = fitPrefix(line, measure, maxWidth);
      lines.push(line.slice(0, cut));
      line = line.slice(cut);
    }
  }
  if (line) lines.push(line);

  if (lines.length <= maxLines) return lines;

  const kept = lines.slice(0, maxLines);
  kept[maxLines - 1] = withEllipsis(kept[maxLines - 1], measure, maxWidth);
  return kept;
}

// The longest prefix that fits, never less than one character so a line always
// makes progress.
function fitPrefix(word, measure, maxWidth) {
  let cut = word.length - 1;
  while (cut > 1 && measure(word.slice(0, cut)) > maxWidth) cut -= 1;
  return Math.max(cut, 1);
}

function withEllipsis(line, measure, maxWidth) {
  let trimmed = line;
  while (trimmed.length > 0 && measure(trimmed + ELLIPSIS) > maxWidth) {
    trimmed = trimmed.slice(0, -1);
  }
  return trimmed.trimEnd() + ELLIPSIS;
}

/**
 * How long a bubble stays up: long enough to read, longer for a longer line,
 * never so long that the next thing said waits behind it.
 * @param {string} text
 * @returns {number} milliseconds
 */
export function bubbleDurationMs(text) {
  const words = String(text).split(/\s+/).filter(Boolean).length;
  return Math.min(Math.max(5000, 2000 + words * 400), 10000);
}
