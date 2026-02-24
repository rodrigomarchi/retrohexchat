/**
 * IRC formatting constants.
 *
 * Extracted from: autocomplete_hook.js, format_toolbar_hook.js
 */

export const IRC_FORMAT_CODES = {
  bold: "\x02",
  italic: "\x1D",
  underline: "\x1F",
  color: "\x03",
  reverse: "\x16",
  reset: "\x0F",
};

/**
 * Mapping from Ctrl+Shift shortcut keys to IRC format codes.
 */
export const SHORTCUT_FORMAT_MAP = {
  b: "\x02", // Bold
  y: "\x1D", // Italic (stYle)
  u: "\x1F", // Underline
  d: "\x03", // Color (Dye)
  v: "\x16", // Reverse (reVerse)
  x: "\x0F", // Reset (Xclear)
};
