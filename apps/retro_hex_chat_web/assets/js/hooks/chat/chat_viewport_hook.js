/**
 * Auto-scroll and reader interactions for the chat message list.
 *
 * Lives on a driver element *outside* the scrolling container and reaches the
 * scroller by id. That placement is the point: `pushEvent` — which this hook
 * does on hover cards, channel tooltips and the context menu — stamps
 * `data-phx-ref-lock` on the element it is pushed from, and LiveView applies
 * every patch arriving while that ref is in flight to a detached clone of that
 * element before swapping it back. A scroller treated that way loses the
 * reader's position; a driver element with no content loses nothing.
 *
 * There is one rule per job and no inference from the shape of a DOM patch:
 *
 *   * pinned  — an IntersectionObserver on a sentinel at the end of the list.
 *               While it is on screen the reader is at the newest message, and
 *               the browser's own scroll anchoring (the sentinel is the only
 *               anchor candidate) keeps it there as lines arrive. The write
 *               below repeats that for Safari, which has no scroll anchoring;
 *               it lands on the same offset, so the two never fight.
 *   * prepend — the distance from the bottom is the invariant a prepended page
 *               must not change. Restoring it needs no before/after height
 *               capture, so it cannot be defeated by when the measurement was
 *               taken or by how many patches the page arrived in.
 *   * reset   — the server says so (`chat_scroll_reset`). A rebuilt list and a
 *               prepended page look identical to an observer.
 */
import { detectContextTarget } from "../../lib/chat/chat.js";
import { insertAtCursor } from "../../lib/chat/input.js";
import {
  scrollToMessage,
  highlightEditingMessage,
  removeEditingHighlight,
} from "../../lib/chat/message_interactions.js";
import {
  isClickNotDrag,
  createTooltip,
  removeTooltip,
  isContextMenuOpen,
  setContextMenuOpen,
  formatChannelTooltip,
  startNickHoverTimer,
  resetNickHoverTimer,
  cancelNickHoverTimer,
} from "../../lib/chat/interactive.js";
import { showFeedbackToast } from "../../lib/notifications/feedback_toast.js";
import { copyText } from "../../lib/ui/dom.js";
import { t } from "../../lib/i18n.js";
import { createLongPress } from "../../lib/input/long_press.js";
import { createViewportScroller } from "../../lib/chat/viewport_scroll.js";

const ChatViewportHook = {
  mounted() {
    this.scroller = document.getElementById("chat-messages");
    this.stream = document.getElementById("chat-message-stream");
    this.anchor = document.getElementById("chat-bottom-anchor");
    if (!this.scroller) return;

    this.mouseDownPos = null;
    this.longPress = createLongPress({
      shouldFire: ({ msgEl }) => msgEl.isConnected,
      onFire: (context) => this.fireLongPress(context),
    });
    this.listeners = [];

    this.viewport = createViewportScroller(this.scroller, {
      stream: this.stream,
      anchor: this.anchor,
    });
    this.viewport.mount();
    this.bindServerEvents();
    this.bindReaderInteractions();
  },

  destroyed() {
    this.longPress.cancel();
    this.viewport.destroy();
    this.listeners.forEach(([el, type, fn, opts]) => el.removeEventListener(type, fn, opts));
    this.listeners = [];
    removeTooltip();
    cancelNickHoverTimer();
  },

  // ── Server-driven events ────────────────────────────────────

  bindServerEvents() {
    this.handleEvent("prepend_start", () => this.viewport.prepareForPrepend());
    this.handleEvent("chat_scroll_reset", () => this.viewport.reset());
    this.handleEvent("scroll_to_bottom", () => this.viewport.pinToBottom());
    this.handleEvent("clear_chat_messages", () => this.viewport.clearMessages());

    this.handleEvent("scroll_to_message", ({ message_id }) => {
      if (!scrollToMessage(message_id)) {
        this.pushEvent("scroll_to_message_missing", { message_id });
      }
    });

    this.handleEvent("enter_edit_mode", ({ message_id, content }) => {
      highlightEditingMessage(message_id);
      const input = document.getElementById("chat-input");
      if (!input) return;

      input.value = content;
      input.focus();
      input.dataset.editMode = "true";
      input.dataset.editMessageId = message_id;
    });

    this.handleEvent("exit_edit_mode", ({ message_id }) => {
      removeEditingHighlight(message_id);
      const input = document.getElementById("chat-input");
      if (!input) return;

      input.value = "";
      delete input.dataset.editMode;
      delete input.dataset.editMessageId;
    });

    this.handleEvent("channel_tooltip", ({ channel, count, joined }) => {
      const el = this.scroller.querySelector(
        `.chat-channel-link[data-channel="${CSS.escape(channel)}"]`,
      );
      if (!el) return;

      const rect = el.getBoundingClientRect();
      createTooltip(formatChannelTooltip(channel, count, joined), rect.left, rect.top);
    });

    this.handleEvent("dismiss_hover_card", () => cancelNickHoverTimer());

    this.handleEvent("clipboard_copy", ({ text }) => {
      copyText(text).then(() => showFeedbackToast(this.el, t("Copied!"), 2000));
    });

    this.handleEvent("clipboard_copy_selection", () => {
      const selection = window.getSelection().toString();
      if (!selection) return;

      copyText(selection).then(() => showFeedbackToast(this.el, t("Copied!"), 2000));
    });

    this.handleEvent("open_url", ({ url }) => {
      window.open(url, "_blank", "noopener,noreferrer");
    });

    this.handleEvent("message_confirmed", ({ temp_id }) => {
      const el = this.scroller.querySelector(`[data-temp-id="${temp_id}"]`);
      if (!el) return;

      el.classList.remove("chat-message--pending");
      el.removeAttribute("data-temp-id");
      el.removeAttribute("data-msg-status");
    });

    this.handleEvent("message_failed", ({ temp_id }) => {
      const el = this.scroller.querySelector(`[data-temp-id="${temp_id}"]`);
      if (!el) return;

      el.classList.remove("chat-message--pending");
      el.classList.add("chat-message--failed");
      el.dataset.msgStatus = "failed";
    });
  },

  // ── Reader interactions ─────────────────────────────────────

  on(el, type, fn, opts) {
    el.addEventListener(type, fn, opts);
    this.listeners.push([el, type, fn, opts]);
  },

  bindReaderInteractions() {
    const list = this.scroller;

    this.on(list, "mouseover", (e) => {
      const channelEl = e.target.closest(".chat-channel-link[data-channel]");
      if (!channelEl || isContextMenuOpen()) return;
      if (channelEl.dataset.channel) {
        this.pushEvent("channel_hover", { channel: channelEl.dataset.channel });
      }
    });

    this.on(list, "mouseout", (e) => {
      if (e.target.closest(".chat-channel-link[data-channel]")) removeTooltip();
    });

    this.on(list, "click", (e) => {
      if (this.longPress.consumeClickSuppression()) {
        e.preventDefault();
        e.stopPropagation();
        return;
      }

      if (isContextMenuOpen()) {
        setContextMenuOpen(false);
        return;
      }

      const pointer = { x: e.clientX, y: e.clientY };

      const channelEl = e.target.closest(".chat-channel-link[data-channel]");
      if (channelEl) {
        if (!isClickNotDrag(this.mouseDownPos, pointer)) return;
        if (channelEl.dataset.channel) {
          removeTooltip();
          this.pushEvent("channel_click", { channel: channelEl.dataset.channel });
        }
        return;
      }

      const nickEl = e.target.closest(".chat-nick[data-nick]");
      if (!nickEl || !nickEl.dataset.nick) return;
      if (!isClickNotDrag(this.mouseDownPos, pointer)) return;

      cancelNickHoverTimer();
      const inputEl = document.querySelector("#chat-input");
      if (inputEl) {
        insertAtCursor(inputEl, nickEl.dataset.nick + ": ");
        inputEl.focus();
      }
    });

    this.on(list, "mousedown", (e) => {
      this.mouseDownPos = { x: e.clientX, y: e.clientY };
      cancelNickHoverTimer();
    });

    this.on(list, "pointerdown", (e) => this.startLongPress(e));
    this.on(list, "pointermove", (e) => this.moveLongPress(e));
    this.on(list, "pointerup", (e) => this.finishLongPress(e));
    this.on(list, "pointercancel", () => this.longPress.cancel());

    this.on(list, "dblclick", (e) => {
      if (isContextMenuOpen()) return;

      const channelEl = e.target.closest(".chat-channel-link");
      if (channelEl) {
        if (channelEl.dataset.channel) {
          this.pushEvent("channel_dblclick", { channel: channelEl.dataset.channel });
        }
        return;
      }

      const nickEl = e.target.closest(".chat-nick[data-nick]");
      if (!nickEl || !nickEl.dataset.nick) return;

      cancelNickHoverTimer();
      this.pushEvent("nick_dblclick", { nick: nickEl.dataset.nick });
    });

    this.on(
      list,
      "mouseenter",
      (e) => {
        if (isContextMenuOpen()) return;
        const nickEl = e.target.closest(".chat-nick[data-nick]");
        if (!nickEl || !nickEl.dataset.nick) return;

        const rect = nickEl.getBoundingClientRect();
        startNickHoverTimer(nickEl.dataset.nick, () => {
          this.pushEvent("nick_hover", {
            nick: nickEl.dataset.nick,
            x: rect.left,
            y: rect.bottom + 4,
          });
        });
      },
      true,
    );

    this.on(list, "mousemove", (e) => {
      const nickEl = e.target.closest(".chat-nick[data-nick]");
      if (!nickEl) return;

      const rect = nickEl.getBoundingClientRect();
      resetNickHoverTimer(() => {
        this.pushEvent("nick_hover", {
          nick: nickEl.dataset.nick,
          x: rect.left,
          y: rect.bottom + 4,
        });
      });
    });

    this.on(
      list,
      "mouseleave",
      (e) => {
        if (!e.target.closest(".chat-nick[data-nick]")) return;
        cancelNickHoverTimer();
        this.pushEvent("nick_hover_dismiss", {});
      },
      true,
    );

    this.on(list, "contextmenu", (e) => {
      if (e.target.closest("textarea, input, [contenteditable]")) return;

      const msgEl = e.target.closest(".chat-message");
      if (!msgEl) return;

      e.preventDefault();
      setContextMenuOpen(true);
      cancelNickHoverTimer();
      removeTooltip();
      this.detectAndPushContextMenu(e, msgEl);
    });

    this.on(document.documentElement, "mouseleave", () => {
      removeTooltip();
      cancelNickHoverTimer();
    });
  },

  detectAndPushContextMenu(e, msgEl) {
    this.pushEvent("chat_context_menu", detectContextTarget(e, msgEl));
  },

  startLongPress(e) {
    if (e.pointerType !== "touch" || e.button !== 0) return;
    if (e.target.closest("textarea, input, [contenteditable]")) return;

    const msgEl = e.target.closest(".chat-message");
    if (!msgEl) return;

    cancelNickHoverTimer();
    removeTooltip();
    this.longPress.start(e.clientX, e.clientY, {
      msgEl,
      target: e.target,
      x: e.clientX,
      y: e.clientY,
    });
  },

  moveLongPress(e) {
    this.longPress.move(e.clientX, e.clientY);
  },

  finishLongPress(e) {
    if (this.longPress.finish()) {
      e.preventDefault();
      e.stopPropagation();
    }
  },

  fireLongPress({ msgEl, target, x, y }) {
    setContextMenuOpen(true);
    cancelNickHoverTimer();
    removeTooltip();
    this.detectAndPushContextMenu({ target, clientX: x, clientY: y }, msgEl);
  },
};

export default ChatViewportHook;
