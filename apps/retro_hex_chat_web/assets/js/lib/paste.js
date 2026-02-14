/**
 * Multi-line paste detection.
 *
 * Determines whether pasted text should be handled as a multi-line paste
 * (sent as individual lines to the server) or as a normal single-line paste
 * (handled by the browser natively).
 */

/**
 * Parses pasted text and returns non-empty lines if it qualifies as multi-line.
 *
 * A paste is "multi-line" when it contains 2+ non-empty lines. Single-line
 * pastes should be handled by the browser's default paste behavior.
 *
 * @param {string} text - The raw pasted text from clipboard
 * @returns {string[]|null} Array of non-empty lines if multi-line, null otherwise
 */
export function parseMultiLinePaste(text) {
  const lines = text.split("\n").filter((l) => l.trim().length > 0);
  return lines.length >= 2 ? lines : null;
}
