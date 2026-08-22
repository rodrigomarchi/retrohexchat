/**
 * "Copy" for the chat log, shared by every menu that offers it.
 *
 * The entry lives in two places — the menu bar's Edit menu and Start ▸ View —
 * and both need the same two things: the row is live only while something
 * inside the chat log is selected, and clicking it copies exactly that. Two
 * engines drive those menus (`menu_bar.js` and `window_manager.js`), so the
 * behaviour sits here rather than in either of them.
 *
 * The DOM contract, unchanged from when the menu bar owned it:
 *
 *   - `[data-menubar-copy-selection]`  the row
 *   - `data-copy-disabled="true|false"` whether it may act
 *   - `.menubar-copy-disabled`          the CSS-owned gray
 *
 * Scoped to `#chat-messages` on purpose: a menu-driven Copy that grabbed any
 * selection on the page would copy the menu's own label as often as a message.
 */

const CHAT_LOG_ID = "chat-messages";

/** The selected text, but only when the selection lies inside the chat log. */
export function selectedChatLogText() {
  if (typeof window.getSelection !== "function") return "";

  const selection = window.getSelection();
  if (!selection || selection.rangeCount === 0) return "";

  const text = selection.toString();
  if (text.trim() === "") return "";

  const chatLog = document.getElementById(CHAT_LOG_ID);
  if (!chatLog) return "";

  try {
    const range = selection.getRangeAt(0);
    return nodeInsideChatLog(range.commonAncestorContainer, chatLog) ? text : "";
  } catch (error) {
    // A range can go stale between the check and the read if the log patched
    // underneath it. Treating that as "nothing selected" is right, but it is
    // still worth saying so rather than swallowing it.
    console.debug("[copy_selection] unreadable selection range", error);
    return "";
  }
}

function nodeInsideChatLog(node, chatLog) {
  if (!node) return false;

  const element = node.nodeType === 1 ? node : node.parentElement;
  return Boolean(element && chatLog.contains(element));
}

/**
 * Syncs every copy row inside `root` to the current selection.
 *
 * Called as a menu opens: the selection cannot change while a menu is up, so
 * there is nothing to watch for continuously.
 */
export function refreshCopySelectionItems(root) {
  if (!root) return;

  const hasSelection = selectedChatLogText() !== "";

  root.querySelectorAll("[data-menubar-copy-selection]").forEach((item) => {
    item.dataset.copyDisabled = hasSelection ? "false" : "true";
    item.setAttribute("aria-disabled", hasSelection ? "false" : "true");
    item.classList.toggle("menubar-copy-disabled", !hasSelection);
  });
}

/** Copies the current chat-log selection. No-op when there is none. */
export function copyCurrentSelection() {
  const text = selectedChatLogText();
  if (!text) return;

  if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
    navigator.clipboard.writeText(text).catch((error) => {
      console.debug("[copy_selection] clipboard write refused, falling back", error);
      copySelectionFallback();
    });
    return;
  }

  copySelectionFallback();
}

function copySelectionFallback() {
  if (typeof document.execCommand === "function") {
    document.execCommand("copy");
  }
}

/**
 * Handles a click that may have landed on a copy row.
 *
 * Returns `true` when it was one — the caller stops there, because the row is
 * neither a window opener nor a server action.
 */
export function handleCopySelectionClick(e) {
  const item = e.target.closest?.("[data-menubar-copy-selection]");
  if (!item) return false;

  e.preventDefault();
  e.stopPropagation();

  const hasSelection = selectedChatLogText() !== "";
  item.dataset.copyDisabled = hasSelection ? "false" : "true";
  item.setAttribute("aria-disabled", hasSelection ? "false" : "true");
  item.classList.toggle("menubar-copy-disabled", !hasSelection);

  if (hasSelection) copyCurrentSelection();

  return true;
}
