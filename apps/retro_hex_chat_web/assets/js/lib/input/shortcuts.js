/**
 * Keyboard shortcut matching logic.
 *
 * Extracted from: shortcut_dispatcher_hook.js, key_binding_capture_hook.js
 */

/**
 * Find the action matching a key in the bindings map.
 *
 * All bindings are Ctrl+Shift combinations.
 *
 * @param {Object} bindings - Map of action → { key, modifiers }
 * @param {string} key - The pressed key (already normalized)
 * @returns {string | null} The matching action or null
 */
export function findShortcutAction(bindings, key) {
  for (const [action, binding] of Object.entries(bindings)) {
    if (!binding) continue;

    const bindingKey = binding.key.length === 1 ? binding.key.toLowerCase() : binding.key;

    const modsMatch =
      binding.modifiers &&
      binding.modifiers.includes("ctrl") &&
      binding.modifiers.includes("shift") &&
      binding.modifiers.length === 2;

    if (modsMatch && bindingKey === key) {
      return action;
    }
  }
  return null;
}

// Physical keys whose character changes under Shift. Every binding is
// Ctrl+Shift, so Ctrl+Shift+/ arrives with key "?" on a US layout, "[" as "{"
// and "1" as "!"; the unshifted character is read from the key's position.
const UNSHIFTED_BY_CODE = {
  Slash: "/",
  Backslash: "\\",
  BracketLeft: "[",
  BracketRight: "]",
  Comma: ",",
  Period: ".",
  Semicolon: ";",
  Quote: "'",
  Minus: "-",
  Equal: "=",
  Backquote: "`",
};

function unshiftedKey(code) {
  if (/^Digit[0-9]$/.test(code)) return code.slice("Digit".length);
  return UNSHIFTED_BY_CODE[code] ?? null;
}

/**
 * The action a Ctrl+Shift keydown triggers.
 *
 * The character the key produced (`event.key`) is tried first, so letters
 * follow the reader's layout (AZERTY's A is "a", wherever it sits). Only when
 * that names no binding is the key's unshifted character tried, from its
 * position (`event.code`) — the case of the digits and punctuation Shift
 * turns into something else.
 *
 * @param {Object} bindings - Map of action → { key, modifiers }
 * @param {{key: string, code?: string}} event
 * @returns {string | null}
 */
export function shortcutActionFor(bindings, event) {
  const typed = event.key.length === 1 ? event.key.toLowerCase() : event.key;
  const action = findShortcutAction(bindings, typed);
  if (action) return action;

  const unshifted = unshiftedKey(event.code || "");
  return unshifted ? findShortcutAction(bindings, unshifted) : null;
}

/**
 * Check if a key is a standalone modifier key.
 *
 * @param {string} key
 * @returns {boolean}
 */
export function isModifierKey(key) {
  return ["Control", "Alt", "Shift", "Meta"].includes(key);
}
