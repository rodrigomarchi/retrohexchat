/**
 * Cells written as one message in mIRC codes: a colour code only where the
 * colour changes, two digits always so a digit drawn next to it is never read
 * as part of it, and every line starting afresh — the chat draws each line of
 * a block on its own, so no colour carries from one line to the next.
 *
 * @module ascii_art/encode
 */

const COLOUR = "\x03";
const RESET = "\x0f";

const two = (n) => String(n).padStart(2, "0");

const blank = (c) => c.ch === " " && c.bg === null;

/** One line of cells in mIRC codes, without the blank cells at its end. */
export function encodeLine(row) {
  let end = row.length;
  while (end > 0 && blank(row[end - 1])) end--;
  let out = "";
  let fg = null;
  let bg = null;
  for (const { ch, fg: f, bg: b } of row.slice(0, end)) {
    if (f === fg && b === bg) {
      out += ch;
      continue;
    }
    // A colour is only taken away by a reset, which takes both.
    if ((f === null && fg !== null) || (b === null && bg !== null)) {
      out += RESET;
      fg = null;
      bg = null;
    }
    if (f !== fg || b !== bg) {
      if (b !== null) out += `${COLOUR}${two(f ?? 1)},${two(b)}`;
      else if (f !== null) out += COLOUR + two(f);
    }
    fg = f;
    bg = b;
    out += ch;
  }
  return out;
}

/** The picture as one message: its lines in mIRC codes, joined by line breaks. */
export function encode(rows) {
  const lines = rows.map(encodeLine);
  while (lines.length && lines.at(-1) === "") lines.pop();
  return lines.join("\n");
}
