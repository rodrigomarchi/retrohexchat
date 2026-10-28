/**
 * The picture ASCII Art makes, before it is text: rows of cells, each a
 * character with a foreground and a background colour (an mIRC colour 0–15,
 * or null for none). The banner, the image and the Hex Paint drawing all make
 * cells; the preview draws them and `encode.js` writes them as one message.
 *
 * @module ascii_art/cells
 */

/** The most lines and columns a block may have: the chat's limits for one. */
export const MAX_LINES = 30;
export const MAX_COLUMNS = 100;

/** A cell of `ch` in `fg` on `bg`. */
export const cell = (ch, fg = null, bg = null) => ({ ch, fg, bg });

/** How many columns the widest row has. */
export const width = (rows) => rows.reduce((most, row) => Math.max(most, row.length), 0);

/** Whether the picture fits one message. */
export const fits = (rows) => rows.length <= MAX_LINES && width(rows) <= MAX_COLUMNS;

/** The picture's text without its colours, a line each. */
export const plainText = (rows) => rows.map((row) => row.map((c) => c.ch).join("")).join("\n");
