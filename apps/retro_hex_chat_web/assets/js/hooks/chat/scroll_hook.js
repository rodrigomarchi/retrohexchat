/**
 * LiveView hook for infinite scroll and auto-scroll in chat messages.
 *
 * - Detects scroll-to-top and pushes "load_more" event
 * - Keeps the newest message visible while the reader stays pinned to bottom
 * - Stops live auto-scroll only after an intentional user scroll up
 * - Preserves scroll position during prepend of older messages
 * - Interactive elements: channel tooltips, nick hover cards, click actions
 */
import {
  isAtBottom as checkIsAtBottom,
  shouldLoadMore,
  detectContextTarget,
  buildMessageText,
  collectUrls,
} from "../../lib/chat/chat.js";
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
import { t } from "../../lib/i18n.js";

const LONG_PRESS_MS = 550;
const MOVE_TOLERANCE_PX = 10;
const USER_SCROLL_INTENT_MS = 1_000;
const SCROLL_INTENT_KEYS = new Set([
  "ArrowUp",
  "ArrowDown",
  "PageUp",
  "PageDown",
  "Home",
  "End",
  " ",
]);

const ScrollHook = {
  mounted() {
    this.chatEl = this.el;
    this.isAtBottom = true;
    this.autoScrollPinned = true;
    this.userScrollIntent = false;
    this.userScrollIntentTimer = null;
    this.pointerScrollIntentActive = false;
    this.initialScrollPending = true;
    this.repinHandle = null;
    this.pendingPrepend = false;
    this.prevScrollHeight = this.chatEl.scrollHeight;
    this.wasHidden = this.isHidden();
    this.mouseDownPos = null;
    this.lastClearToken = this.el.dataset.clearToken || "";
    this.longPress = null;
    this.suppressNextClick = false;

    // Pin to the bottom on mount, then re-pin once after the next frame so
    // late layout (flex sizing, web fonts, initial stream patches) that grows
    // the list can't strand the view above the newest message.
    this.repinToBottom();

    // Listen for scroll events
    this.chatEl.addEventListener("scroll", () => {
      this.handleScroll();
    });

    this._markUserScrollIntent = () => this.markUserScrollIntent();
    this._keyScrollIntent = (e) => {
      if (SCROLL_INTENT_KEYS.has(e.key)) this.markUserScrollIntent();
    };
    this.chatEl.addEventListener("wheel", this._markUserScrollIntent, { passive: true });
    this.chatEl.addEventListener("touchstart", this._markUserScrollIntent, { passive: true });
    this.chatEl.addEventListener("touchmove", this._markUserScrollIntent, { passive: true });
    this.chatEl.addEventListener("keydown", this._keyScrollIntent);

    // Server-side affordances can still request an explicit return to bottom.
    this.handleEvent("scroll_to_bottom", () => {
      this.autoScrollPinned = true;
      this.scrollToBottom();
    });

    this.handleEvent("clear_chat_messages", () => {
      this.clearMessages();
    });

    this.handleEvent("scroll_to_message", ({ message_id }) => {
      if (!scrollToMessage(message_id)) {
        this.pushEvent("scroll_to_message_missing", { message_id });
      }
    });

    this.handleEvent("enter_edit_mode", ({ message_id, content }) => {
      highlightEditingMessage(message_id);

      const input = document.getElementById("chat-input");
      if (input) {
        input.value = content;
        input.focus();
        input.dataset.editMode = "true";
        input.dataset.editMessageId = message_id;
      }
    });

    this.handleEvent("exit_edit_mode", ({ message_id }) => {
      removeEditingHighlight(message_id);

      const input = document.getElementById("chat-input");
      if (input) {
        input.value = "";
        delete input.dataset.editMode;
        delete input.dataset.editMessageId;
      }
    });

    // Listen for link preview results
    this.handleEvent("link_preview", ({ url, title }) => {
      const links = this.chatEl.querySelectorAll(`a.chat-link[href="${CSS.escape(url)}"]`);
      links.forEach((link) => {
        // Update title attribute so native tooltip shows page title
        if (title) {
          link.title = title;
        }

        if (
          !link.nextElementSibling ||
          !link.nextElementSibling.classList.contains("chat-link-preview")
        ) {
          const preview = document.createElement("span");
          preview.className = "chat-link-preview";
          preview.textContent = title;
          link.after(preview);
        }
      });

      // Inserting a preview grows the row; keep the newest message in view if
      // we were already pinned to the bottom.
      if (this.autoScrollPinned) {
        this.scrollToBottom();
      }
    });

    // ── Interactive elements: Channel hover/click ───────────────

    // Channel tooltip response from server
    this.handleEvent("channel_tooltip", ({ channel, count, joined }) => {
      const el = this.chatEl.querySelector(
        `.chat-channel-link[data-channel="${CSS.escape(channel)}"]`,
      );
      if (el) {
        const rect = el.getBoundingClientRect();
        createTooltip(formatChannelTooltip(channel, count, joined), rect.left, rect.top);
      }
    });

    // Channel hover — request tooltip data from server
    this.chatEl.addEventListener("mouseover", (e) => {
      const channelEl = e.target.closest(".chat-channel-link[data-channel]");
      if (channelEl && !isContextMenuOpen()) {
        const channel = channelEl.dataset.channel;
        if (channel) {
          this.pushEvent("channel_hover", { channel });
        }
      }
    });

    // Channel/tooltip mouseleave — remove tooltip
    this.chatEl.addEventListener("mouseout", (e) => {
      const channelEl = e.target.closest(".chat-channel-link[data-channel]");
      if (channelEl) {
        removeTooltip();
      }
    });

    // Channel single-click — join or switch
    this.chatEl.addEventListener("click", (e) => {
      if (this.suppressNextClick) {
        e.preventDefault();
        e.stopPropagation();
        this.suppressNextClick = false;
        return;
      }

      if (isContextMenuOpen()) {
        setContextMenuOpen(false);
        return;
      }

      const channelEl = e.target.closest(".chat-channel-link[data-channel]");
      if (channelEl) {
        if (!isClickNotDrag(this.mouseDownPos, { x: e.clientX, y: e.clientY })) return;
        const channel = channelEl.dataset.channel;
        if (channel) {
          removeTooltip();
          this.pushEvent("channel_click", { channel });
        }
        return;
      }

      // Nick single-click — insert "Nick: " into input (client-only)
      const nickEl = e.target.closest(".chat-nick[data-nick]");
      if (nickEl) {
        if (!isClickNotDrag(this.mouseDownPos, { x: e.clientX, y: e.clientY })) return;
        const nick = nickEl.dataset.nick;
        if (nick) {
          cancelNickHoverTimer();
          const inputEl = document.querySelector("#chat-input");
          if (inputEl) {
            insertAtCursor(inputEl, nick + ": ");
            inputEl.focus();
          }
        }
      }
    });

    // Track mousedown position for click-vs-drag detection (FR-020)
    this.chatEl.addEventListener("mousedown", (e) => {
      this.mouseDownPos = { x: e.clientX, y: e.clientY };
      // Cancel nick hover timer on mousedown (FR-015 — text selection suppression)
      cancelNickHoverTimer();
    });

    this._pointerDown = (e) => {
      this.pointerScrollIntentActive = true;
      this.markUserScrollIntent();
      this.startLongPress(e);
    };
    this._pointerMove = (e) => {
      if (this.pointerScrollIntentActive) this.markUserScrollIntent();
      this.moveLongPress(e);
    };
    this._pointerUp = (e) => {
      this.pointerScrollIntentActive = false;
      this.finishLongPress(e);
    };
    this._pointerCancel = () => {
      this.pointerScrollIntentActive = false;
      this.cancelLongPress();
    };

    this.chatEl.addEventListener("pointerdown", this._pointerDown);
    this.chatEl.addEventListener("pointermove", this._pointerMove);
    this.chatEl.addEventListener("pointerup", this._pointerUp);
    this.chatEl.addEventListener("pointercancel", this._pointerCancel);

    // Double-click on channel names in chat → join/switch channel (legacy, keep for compat)
    this.chatEl.addEventListener("dblclick", (e) => {
      if (isContextMenuOpen()) return;

      const channelEl = e.target.closest(".chat-channel-link");
      if (channelEl) {
        const channel = channelEl.dataset.channel;
        if (channel) {
          this.pushEvent("channel_dblclick", { channel });
        }
        return;
      }

      // Nick double-click — open PM conversation
      const nickEl = e.target.closest(".chat-nick[data-nick]");
      if (nickEl) {
        const nick = nickEl.dataset.nick;
        if (nick) {
          cancelNickHoverTimer();
          this.pushEvent("nick_dblclick", { nick });
        }
      }
    });

    // ── Interactive elements: Nick hover card ───────────────────

    // Nick mouseenter — start 500ms idle timer
    this.chatEl.addEventListener(
      "mouseenter",
      (e) => {
        if (isContextMenuOpen()) return;
        const nickEl = e.target.closest(".chat-nick[data-nick]");
        if (!nickEl) return;

        const nick = nickEl.dataset.nick;
        if (!nick) return;

        const rect = nickEl.getBoundingClientRect();
        startNickHoverTimer(nick, () => {
          this.pushEvent("nick_hover", {
            nick,
            x: rect.left,
            y: rect.bottom + 4,
          });
        });
      },
      true,
    );

    // Nick mousemove — reset timer (only fires after 500ms of no movement)
    this.chatEl.addEventListener("mousemove", (e) => {
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

    // Nick mouseleave — cancel timer and dismiss hover card
    this.chatEl.addEventListener(
      "mouseleave",
      (e) => {
        const nickEl = e.target.closest(".chat-nick[data-nick]");
        if (nickEl) {
          cancelNickHoverTimer();
          this.pushEvent("nick_hover_dismiss", {});
        }
      },
      true,
    );

    // ── Context menu coordination ──────────────────────────────

    // Smart right-click context menu detection
    this.chatEl.addEventListener("contextmenu", (e) => {
      if (e.target.closest("textarea, input, [contenteditable]")) return;

      const msgEl = e.target.closest(".chat-message");
      if (!msgEl) return;

      e.preventDefault();
      setContextMenuOpen(true);
      cancelNickHoverTimer();
      removeTooltip();
      this.detectAndPushContextMenu(e, msgEl);
    });

    // Dismiss hover card from server (e.g., nick change)
    this.handleEvent("dismiss_hover_card", () => {
      cancelNickHoverTimer();
    });

    // Clipboard copy handler (server → client)
    this.handleEvent("clipboard_copy", ({ text }) => {
      navigator.clipboard.writeText(text).then(() => {
        showFeedbackToast(this.el, t("Copied!"), 2000);
      });
    });

    // Copy selection handler (server → client)
    this.handleEvent("clipboard_copy_selection", () => {
      const selection = window.getSelection().toString();
      if (selection) {
        navigator.clipboard.writeText(selection).then(() => {
          showFeedbackToast(this.el, t("Copied!"), 2000);
        });
      }
    });

    // Open URL handler (server → client)
    this.handleEvent("open_url", ({ url }) => {
      window.open(url, "_blank", "noopener,noreferrer");
    });

    // Optimistic send: message confirmed by server
    this.handleEvent("message_confirmed", ({ temp_id }) => {
      const el = this.chatEl.querySelector(`[data-temp-id="${temp_id}"]`);
      if (el) {
        el.classList.remove("chat-message--pending");
        el.removeAttribute("data-temp-id");
        el.removeAttribute("data-msg-status");
      }
    });

    // Optimistic send: message failed
    this.handleEvent("message_failed", ({ temp_id }) => {
      const el = this.chatEl.querySelector(`[data-temp-id="${temp_id}"]`);
      if (el) {
        el.classList.remove("chat-message--pending");
        el.classList.add("chat-message--failed");
        el.dataset.msgStatus = "failed";
      }
    });

    // Listen for prepend start (before DOM update)
    this.handleEvent("prepend_start", () => {
      this.pendingPrepend = true;
      this.prevScrollHeight = this.chatEl.scrollHeight;
    });

    // ── Viewport mouseleave cleanup (FR-019) ───────────────────
    this._viewportLeaveHandler = () => {
      removeTooltip();
      cancelNickHoverTimer();
    };
    document.documentElement.addEventListener("mouseleave", this._viewportLeaveHandler);

    // Re-pin continuously as content settles. The ResizeObserver callback runs
    // after layout but before paint, so pinning here (unlike a rAF/timeout) is
    // applied in the same frame the content grows — no visible "jump up then
    // snap down", and no stranding above the newest message when rows, web
    // fonts, avatars, or images land late (e.g. returning from a virtual space
    // or another channel). Only pins while live auto-scroll is enabled.
    this.setupResizeObserver();

    // Observe DOM mutations for auto-scroll and prepend handling
    this.observer = new MutationObserver((mutations) => {
      if (!mutations.some((mutation) => this.isMessageStreamMutation(mutation))) {
        return;
      }

      this.syncRowObservations(mutations);

      if (this.pendingPrepend) {
        const newScrollHeight = this.chatEl.scrollHeight;
        const heightDiff = newScrollHeight - this.prevScrollHeight;
        this.chatEl.scrollTop += heightDiff;
        this.pendingPrepend = false;
      } else if (this.initialScrollPending) {
        this.scrollToBottom();
      } else if (this.isStreamResetMutation(mutations)) {
        this.repinToBottom();
      } else if (this.autoScrollPinned) {
        this.scrollToBottom();
      } else {
        this.isAtBottom = checkIsAtBottom(this.chatEl);
      }
    });

    this.observer.observe(this.chatEl, { childList: true, subtree: true });
  },

  // Keep the view glued to the bottom whenever the content box or any message
  // row changes size, provided the reader had not scrolled up. Runs pre-paint.
  setupResizeObserver() {
    if (typeof window.ResizeObserver !== "function") return;

    this.resizeObserver = new ResizeObserver(() => {
      if (this.pendingPrepend || !this.autoScrollPinned || this.isHidden()) return;
      this.scrollToBottom();
    });

    // The container catches panel/window resizes and hidden→visible; the rows
    // catch late per-message growth (images, link previews, wrapped text).
    this.resizeObserver.observe(this.chatEl);
    this.chatEl
      .querySelectorAll("[data-message-id]")
      .forEach((row) => this.resizeObserver.observe(row));
  },

  syncRowObservations(mutations) {
    if (!this.resizeObserver) return;

    for (const mutation of mutations) {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE && node.matches?.("[data-message-id]")) {
          this.resizeObserver.observe(node);
        }
      });
      mutation.removedNodes.forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE && node.matches?.("[data-message-id]")) {
          this.resizeObserver.unobserve(node);
        }
      });
    }
  },

  clearMessages() {
    this.chatEl.replaceChildren();
    this.isAtBottom = true;
    this.autoScrollPinned = true;
    this.pendingPrepend = false;
    this.prevScrollHeight = this.chatEl.scrollHeight;
  },

  updated() {
    const clearToken = this.el.dataset.clearToken || "";
    if (clearToken !== this.lastClearToken) {
      this.lastClearToken = clearToken;
      this.clearMessages();
    }

    const hidden = this.isHidden();
    if (hidden) {
      this.wasHidden = true;
      return;
    }

    if (this.wasHidden) {
      this.wasHidden = false;
      this.repinToBottom();
      return;
    }

    if (this.autoScrollPinned) {
      this.scrollToBottom();
    }
  },

  destroyed() {
    this.cancelLongPress();
    this.cancelRepin();
    this.clearUserScrollIntent();
    if (this.observer) {
      this.observer.disconnect();
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    if (this._viewportLeaveHandler) {
      document.documentElement.removeEventListener("mouseleave", this._viewportLeaveHandler);
    }
    this.chatEl.removeEventListener("wheel", this._markUserScrollIntent);
    this.chatEl.removeEventListener("touchstart", this._markUserScrollIntent);
    this.chatEl.removeEventListener("touchmove", this._markUserScrollIntent);
    this.chatEl.removeEventListener("keydown", this._keyScrollIntent);
    this.chatEl.removeEventListener("pointerdown", this._pointerDown);
    this.chatEl.removeEventListener("pointermove", this._pointerMove);
    this.chatEl.removeEventListener("pointerup", this._pointerUp);
    this.chatEl.removeEventListener("pointercancel", this._pointerCancel);
    removeTooltip();
    cancelNickHoverTimer();
  },

  handleScroll() {
    if (this.initialScrollPending) {
      this.isAtBottom = true;
      this.autoScrollPinned = true;
      return;
    }

    this.isAtBottom = checkIsAtBottom(this.chatEl);

    if (this.isAtBottom) {
      this.autoScrollPinned = true;
      this.clearUserScrollIntent();
    } else if (this.userScrollIntent) {
      this.autoScrollPinned = false;
    } else if (this.autoScrollPinned) {
      this.scrollToBottom();
    }

    if (this.userScrollIntent && shouldLoadMore(this.chatEl.scrollTop)) {
      this.pushEvent("load_more", {});
    }
  },

  scrollToBottom() {
    this.chatEl.scrollTop = this.chatEl.scrollHeight;
    this.isAtBottom = true;
    this.autoScrollPinned = true;
  },

  // Pin to the bottom now, then correct once on the next frame. The immediate
  // scroll runs before paint (invisible); the single follow-up catches late
  // layout that grew the list (streamed rows, web fonts) without the visible
  // multi-frame "jump up then settle back down" the old rAF+timeout loop caused.
  repinToBottom() {
    this.cancelRepin();
    this.initialScrollPending = true;
    this.scrollToBottom();

    if (typeof window.requestAnimationFrame !== "function") {
      this.initialScrollPending = false;
      return;
    }

    this.repinHandle = window.requestAnimationFrame(() => {
      this.repinHandle = null;
      this.initialScrollPending = false;

      if (!this.chatEl?.isConnected) return;

      this.scrollToBottom();
    });
  },

  cancelRepin() {
    if (this.repinHandle && typeof window.cancelAnimationFrame === "function") {
      window.cancelAnimationFrame(this.repinHandle);
    }
    this.repinHandle = null;
  },

  isHidden() {
    return (
      this.chatEl.hidden ||
      this.chatEl.classList.contains("hidden") ||
      !!this.chatEl.closest(".hidden")
    );
  },

  markUserScrollIntent() {
    this.userScrollIntent = true;
    if (this.userScrollIntentTimer) clearTimeout(this.userScrollIntentTimer);
    this.userScrollIntentTimer = setTimeout(() => {
      this.userScrollIntent = false;
      this.userScrollIntentTimer = null;
    }, USER_SCROLL_INTENT_MS);
  },

  clearUserScrollIntent() {
    if (this.userScrollIntentTimer) {
      clearTimeout(this.userScrollIntentTimer);
    }
    this.userScrollIntent = false;
    this.userScrollIntentTimer = null;
  },

  detectAndPushContextMenu(e, msgEl) {
    const payload = detectContextTarget(e, msgEl);
    this.pushEvent("chat_context_menu", payload);
  },

  buildMessageText(msgEl) {
    return buildMessageText(msgEl);
  },

  collectUrls(msgEl) {
    return collectUrls(msgEl);
  },

  startLongPress(e) {
    if (e.pointerType !== "touch" || e.button !== 0) return;
    if (e.target.closest("textarea, input, [contenteditable]")) return;

    const msgEl = e.target.closest(".chat-message");
    if (!msgEl) return;

    this.cancelLongPress();
    cancelNickHoverTimer();
    removeTooltip();
    this.longPress = {
      msgEl,
      target: e.target,
      x: e.clientX,
      y: e.clientY,
      fired: false,
      timer: setTimeout(() => this.fireLongPress(), LONG_PRESS_MS),
    };
  },

  moveLongPress(e) {
    if (!this.longPress) return;
    if (this.longPress.fired) return;

    const dx = Math.abs(e.clientX - this.longPress.x);
    const dy = Math.abs(e.clientY - this.longPress.y);
    if (dx > MOVE_TOLERANCE_PX || dy > MOVE_TOLERANCE_PX) {
      this.cancelLongPress();
    }
  },

  finishLongPress(e) {
    if (this.longPress?.fired) {
      e.preventDefault();
      e.stopPropagation();
    }
    this.cancelLongPress({ keepClickSuppression: true });
  },

  fireLongPress() {
    if (!this.longPress) return;

    const { msgEl, target, x, y } = this.longPress;
    if (!msgEl.isConnected) {
      this.cancelLongPress();
      return;
    }

    this.longPress.fired = true;
    this.suppressNextClick = true;
    setContextMenuOpen(true);
    cancelNickHoverTimer();
    removeTooltip();
    this.detectAndPushContextMenu({ target, clientX: x, clientY: y }, msgEl);
  },

  cancelLongPress({ keepClickSuppression = false } = {}) {
    if (this.longPress?.timer) clearTimeout(this.longPress.timer);
    this.longPress = null;
    if (!keepClickSuppression) this.suppressNextClick = false;
  },

  isMessageStreamMutation(mutation) {
    if (mutation.target === this.chatEl) return true;

    const nodes = [...mutation.addedNodes, ...mutation.removedNodes];

    return nodes.some((node) => {
      if (node.nodeType !== Node.ELEMENT_NODE) return false;
      return node.matches?.("[data-message-id]") || node.querySelector?.("[data-message-id]");
    });
  },

  isStreamResetMutation(mutations) {
    let addedMessage = false;
    let removedMessage = false;

    for (const mutation of mutations) {
      if (mutation.type !== "childList") continue;

      addedMessage ||= this.hasMessageNode(mutation.addedNodes);
      removedMessage ||= this.hasMessageNode(mutation.removedNodes);

      if (addedMessage && removedMessage) return true;
    }

    return false;
  },

  hasMessageNode(nodes) {
    return [...nodes].some((node) => {
      if (node.nodeType !== Node.ELEMENT_NODE) return false;
      return node.matches?.("[data-message-id]") || node.querySelector?.("[data-message-id]");
    });
  },
};

export default ScrollHook;
