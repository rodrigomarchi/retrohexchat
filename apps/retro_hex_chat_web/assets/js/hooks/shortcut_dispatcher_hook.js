/**
 * Global keyboard shortcut dispatcher hook.
 *
 * Receives the user's keybinding map via `update_bindings` push_event,
 * listens for document-level keydown, and pushes `shortcut_action` events
 * to the server for matched shortcuts.
 *
 * Uses bubble-up pattern: checks `e.defaultPrevented` to let per-element
 * hooks (formatting shortcuts in AutocompleteHook) handle events first.
 */
const ShortcutDispatcherHook = {
  mounted() {
    this.bindings = {};

    this.handleEvent("update_bindings", ({ bindings }) => {
      this.bindings = bindings || {};
    });

    this.keydownHandler = (e) => {
      // Bubble-up: if another hook already handled this, skip
      if (e.defaultPrevented) return;

      // Only intercept Ctrl+Shift combinations (our web-safe pattern)
      if (!e.ctrlKey || !e.shiftKey) return;

      // Don't intercept if Alt is also pressed
      if (e.altKey) return;

      const key = e.key.length === 1 ? e.key.toLowerCase() : e.key;
      const action = this.findAction(key);

      if (action) {
        e.preventDefault();
        e.stopPropagation();
        this.pushEvent("shortcut_action", { action });
      }
    };

    document.addEventListener("keydown", this.keydownHandler, false);
  },

  destroyed() {
    if (this.keydownHandler) {
      document.removeEventListener("keydown", this.keydownHandler, false);
    }
  },

  findAction(key) {
    for (const [action, binding] of Object.entries(this.bindings)) {
      if (!binding) continue;

      const bindingKey =
        binding.key.length === 1 ? binding.key.toLowerCase() : binding.key;

      // All our bindings are Ctrl+Shift, so we just compare the key
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
  },
};

export default ShortcutDispatcherHook;
