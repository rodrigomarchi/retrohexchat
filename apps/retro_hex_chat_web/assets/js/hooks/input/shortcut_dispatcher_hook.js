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
import { findShortcutAction } from "../../lib/input/shortcuts.js";

function isEditableTarget(target) {
  if (!(target instanceof Element)) return false;

  return !!target.closest(
    'input, textarea, select, [contenteditable=""], [contenteditable="true"], [role="textbox"]',
  );
}

function isConferenceAction(action) {
  return typeof action === "string" && action.startsWith("group_call_");
}

const ShortcutDispatcherHook = {
  mounted() {
    this.bindings = {};

    this.handleEvent("update_bindings", ({ bindings }) => {
      this.bindings = bindings || {};
    });

    this.keydownHandler = (e) => {
      if (e.defaultPrevented) return;

      if (!e.ctrlKey || !e.shiftKey) return;
      if (e.altKey) return;

      const key = e.key.length === 1 ? e.key.toLowerCase() : e.key;
      const action = findShortcutAction(this.bindings, key);

      if (action) {
        if (isConferenceAction(action) && isEditableTarget(e.target)) return;

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
};

export default ShortcutDispatcherHook;
