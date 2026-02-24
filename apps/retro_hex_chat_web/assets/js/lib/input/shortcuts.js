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

/**
 * Check if a key is a standalone modifier key.
 *
 * @param {string} key
 * @returns {boolean}
 */
export function isModifierKey(key) {
  return ["Control", "Alt", "Shift", "Meta"].includes(key);
}
