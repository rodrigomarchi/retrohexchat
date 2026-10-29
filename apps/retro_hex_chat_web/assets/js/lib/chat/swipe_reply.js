/**
 * Swiping a line to the right answers it — the gesture phones already teach.
 *
 * Touch only. The line follows the finger (through the CSS-owned
 * `chat-message--swiping` class and the `--swipe-x` custom property) and a
 * release past the threshold asks for a reply to it, exactly as the menu's
 * Reply would. A mostly vertical drag is left to the scroll, and narration —
 * a system line, a line that never reached the server — is not something to
 * answer.
 *
 * @module chat/swipe_reply
 */

/** How far right the finger has to carry the line to answer it. */
export const SWIPE_REPLY_PX = 64;
/** How far the line follows before it stops, so it never leaves the screen. */
const SWIPE_MAX_PX = 96;
/** Movement under this is a press still deciding what it is. */
const DECIDE_PX = 8;

const ROW = ".chat-message";
const SWIPING = "chat-message--swiping";

/**
 * What a drag is, from how far it has moved.
 *
 * @param {number} dx horizontal travel, right positive
 * @param {number} dy vertical travel
 * @returns {"undecided" | "scroll" | "swipe"}
 */
export function swipeIntent(dx, dy) {
  if (Math.abs(dx) < DECIDE_PX && Math.abs(dy) < DECIDE_PX) return "undecided";
  if (dx <= 0 || Math.abs(dy) > Math.abs(dx)) return "scroll";
  return "swipe";
}

/** Whether a row is a line somebody could answer. */
function answerable(row) {
  return row.dataset.systemMessage !== "true" && /^\d+$/.test(row.dataset.realId || "");
}

/**
 * @param {HTMLElement} root the conversation the rows live in
 * @param {{ onReply: (row: HTMLElement) => void }} ports
 * @returns {{ mount(): void, destroy(): void }}
 */
export function createSwipeReply(root, { onReply }) {
  let drag = null;

  const release = () => {
    if (!drag) return;
    drag.row.classList.remove(SWIPING);
    drag.row.style.removeProperty("--swipe-x");
    drag = null;
  };

  const down = (event) => {
    if (event.pointerType !== "touch" || event.button !== 0) return;
    if (event.target.closest("textarea, input, [contenteditable], a, button, summary")) return;

    const row = event.target.closest(ROW);
    if (!row || !answerable(row)) return;

    drag = { row, x: event.clientX, y: event.clientY, intent: "undecided", dx: 0 };
  };

  const move = (event) => {
    if (!drag) return;

    const dx = event.clientX - drag.x;
    if (drag.intent === "undecided") drag.intent = swipeIntent(dx, event.clientY - drag.y);
    if (drag.intent === "scroll") return release();
    if (drag.intent !== "swipe") return;

    drag.dx = dx;
    drag.row.classList.add(SWIPING);
    drag.row.style.setProperty("--swipe-x", `${Math.min(Math.max(dx, 0), SWIPE_MAX_PX)}px`);
  };

  const up = () => {
    if (drag && drag.intent === "swipe" && drag.dx >= SWIPE_REPLY_PX) onReply(drag.row);
    release();
  };

  const listeners = [
    ["pointerdown", down],
    ["pointermove", move],
    ["pointerup", up],
    ["pointercancel", release],
  ];

  return {
    mount() {
      listeners.forEach(([type, fn]) => root.addEventListener(type, fn));
    },
    destroy() {
      listeners.forEach(([type, fn]) => root.removeEventListener(type, fn));
      release();
    },
  };
}
