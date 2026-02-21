/**
 * Input processing utilities for the chat input.
 *
 * Extracted from: autocomplete_hook.js, format_toolbar_hook.js, emoji_picker_hook.js
 */

/**
 * Insert text at the current cursor position in an input/textarea.
 *
 * @param {HTMLInputElement|HTMLTextAreaElement} el
 * @param {string} text
 */
export function insertAtCursor(el, text) {
  const start = el.selectionStart;
  const end = el.selectionEnd;
  const value = el.value;
  el.value = value.slice(0, start) + text + value.slice(end);
  el.selectionStart = el.selectionEnd = start + text.length;
  el.dispatchEvent(new Event("input", { bubbles: true }));
}

/**
 * Detect an autocomplete trigger in the input value.
 *
 * @param {string} value - Current input value
 * @param {number} cursorPos - Cursor position
 * @param {Function} getArgContext - Function to resolve command argument context
 * @returns {{ type: string, partial: string, command?: string } | null}
 */
export function detectTrigger(value, cursorPos, getArgContext) {
  if (!value) return null;

  // Command trigger: "/" at position 0
  if (value.startsWith("/") && !value.includes(" ")) {
    return { type: "command", partial: value.slice(1) };
  }

  // Command argument trigger: "/command " followed by partial arg
  if (value.startsWith("/")) {
    const spaceIdx = value.indexOf(" ");
    if (spaceIdx > 1) {
      const cmdName = value.slice(1, spaceIdx);
      const argText = value.slice(spaceIdx + 1);
      const argContext = getArgContext(cmdName);
      if (argContext && argText.length >= 0) {
        return { type: argContext, partial: argText, command: cmdName };
      }
    }
  }

  // Nick trigger: "@" at word boundary
  const textBeforeCursor = value.slice(0, cursorPos);

  for (let i = textBeforeCursor.length - 1; i >= 0; i--) {
    const ch = textBeforeCursor[i];
    if (ch === " " || ch === "\t") break;
    if (ch === "@") {
      const isWordBoundary = i === 0 || /\s/.test(textBeforeCursor[i - 1]);
      if (isWordBoundary) {
        const partial = textBeforeCursor.slice(i + 1);
        if (partial.length >= 1) {
          return { type: "nick", partial };
        }
      }
      break;
    }
  }

  // Channel trigger: "#" at word boundary
  for (let i = textBeforeCursor.length - 1; i >= 0; i--) {
    const ch = textBeforeCursor[i];
    if (ch === " " || ch === "\t") break;
    if (ch === "#") {
      const isWordBoundary = i === 0 || /\s/.test(textBeforeCursor[i - 1]);
      if (isWordBoundary) {
        const partial = textBeforeCursor.slice(i + 1);
        if (partial.length >= 1) {
          return { type: "channel", partial };
        }
      }
      break;
    }
  }

  return null;
}

/**
 * Determine the argument context for a command name.
 *
 * @param {string} cmdName
 * @returns {"arg_nick" | "arg_channel" | null}
 */
export function getArgumentContext(cmdName) {
  const nickAll = ["msg", "query", "whois", "whowas", "notice", "ctcp", "invite"];
  const nickCurrent = ["kick", "ban", "call", "p2p", "sendfile"];
  const channel = ["join", "part", "topic", "mode"];

  if (nickAll.includes(cmdName)) return "arg_nick";
  if (nickCurrent.includes(cmdName)) return "arg_nick";
  if (channel.includes(cmdName)) return "arg_channel";
  return null;
}

/**
 * Compute the max height for a textarea based on line count.
 *
 * @param {HTMLTextAreaElement} el
 * @param {number} maxLines
 * @returns {number} maxHeight in pixels
 */
export function computeMaxHeight(el, maxLines) {
  const style = getComputedStyle(el);
  const lineHeight = parseFloat(style.lineHeight) || 18.2;
  const paddingTop = parseFloat(style.paddingTop) || 0;
  const paddingBottom = parseFloat(style.paddingBottom) || 0;
  const borderTop = parseFloat(style.borderTopWidth) || 0;
  const borderBottom = parseFloat(style.borderBottomWidth) || 0;
  return lineHeight * maxLines + paddingTop + paddingBottom + borderTop + borderBottom;
}

/**
 * Auto-resize a textarea up to a maximum height.
 *
 * @param {HTMLTextAreaElement} el
 * @param {number} maxHeight
 */
export function autoResize(el, maxHeight) {
  el.style.height = "auto";
  const newHeight = Math.min(el.scrollHeight, maxHeight);
  el.style.height = newHeight + "px";
  el.style.overflowY = el.scrollHeight > maxHeight ? "auto" : "hidden";
}
