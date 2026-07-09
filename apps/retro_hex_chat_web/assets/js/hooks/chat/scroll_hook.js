/**
 * LiveView hook for infinite scroll and auto-scroll in chat messages.
 *
 * - Detects scroll-to-top and pushes "load_more" event
 * - Auto-scrolls to bottom when at bottom and new message arrives
 * - Shows "New messages" button when scrolled up and new message arrives
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

const ScrollHook = {
  mounted() {
    this.chatEl = this.el;
    this.isAtBottom = true;
    this.initialScrollPending = true;
    this.repinHandle = null;
    this.pendingPrepend = false;
    this.prevScrollHeight = this.chatEl.scrollHeight;
    this.wasHidden = this.isHidden();
    this.mouseDownPos = null;
    this.lastClearToken = this.el.dataset.clearToken || "";

    // Pin to the bottom on mount, then re-pin once after the next frame so
    // late layout (flex sizing, web fonts, initial stream patches) that grows
    // the list can't strand the view above the newest message.
    this.repinToBottom();

    // Listen for scroll events
    this.chatEl.addEventListener("scroll", () => {
      this.handleScroll();
    });

    // Listen for new messages button click
    this.handleEvent("scroll_to_bottom", () => {
      this.scrollToBottom();
      this.hideNewMessagesButton();
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
      if (this.isAtBottom) {
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
    // or another channel). Only pins while the reader is already at the bottom.
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
        this.hideNewMessagesButton();
      } else if (this.isStreamResetMutation(mutations)) {
        this.repinToBottom();
      } else if (this.isAtBottom) {
        this.scrollToBottom();
      } else {
        this.showNewMessagesButton();
      }
    });

    this.observer.observe(this.chatEl, { childList: true, subtree: true });
  },

  // Keep the view glued to the bottom whenever the content box or any message
  // row changes size, provided the reader had not scrolled up. Runs pre-paint.
  setupResizeObserver() {
    if (typeof window.ResizeObserver !== "function") return;

    this.resizeObserver = new ResizeObserver(() => {
      if (this.pendingPrepend || !this.isAtBottom || this.isHidden()) return;
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
    this.pendingPrepend = false;
    this.prevScrollHeight = this.chatEl.scrollHeight;
    this.hideNewMessagesButton();
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

    if (this.isAtBottom) {
      this.scrollToBottom();
    }
  },

  destroyed() {
    this.cancelRepin();
    if (this.observer) {
      this.observer.disconnect();
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    if (this._viewportLeaveHandler) {
      document.documentElement.removeEventListener("mouseleave", this._viewportLeaveHandler);
    }
    removeTooltip();
    cancelNickHoverTimer();
  },

  handleScroll() {
    if (this.initialScrollPending) {
      this.isAtBottom = true;
      this.hideNewMessagesButton();
      return;
    }

    this.isAtBottom = checkIsAtBottom(this.chatEl);

    if (this.isAtBottom) {
      this.hideNewMessagesButton();
    }

    if (shouldLoadMore(this.chatEl.scrollTop)) {
      this.pushEvent("load_more", {});
    }
  },

  scrollToBottom() {
    this.chatEl.scrollTop = this.chatEl.scrollHeight;
    this.isAtBottom = true;
  },

  // Pin to the bottom now, then correct once on the next frame. The immediate
  // scroll runs before paint (invisible); the single follow-up catches late
  // layout that grew the list (streamed rows, web fonts) without the visible
  // multi-frame "jump up then settle back down" the old rAF+timeout loop caused.
  repinToBottom() {
    this.cancelRepin();
    this.initialScrollPending = true;
    this.scrollToBottom();
    this.hideNewMessagesButton();

    if (typeof window.requestAnimationFrame !== "function") {
      this.initialScrollPending = false;
      return;
    }

    this.repinHandle = window.requestAnimationFrame(() => {
      this.repinHandle = null;
      this.initialScrollPending = false;

      if (!this.chatEl?.isConnected) return;

      this.scrollToBottom();
      this.hideNewMessagesButton();
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

  showNewMessagesButton() {
    if (!this.chatEl.parentElement) return;

    let btn = this.chatEl.parentElement.querySelector(".new-messages-btn");
    if (!btn) {
      btn = document.createElement("button");
      btn.className = "new-messages-btn";
      btn.textContent = t("New messages");
      btn.addEventListener("click", () => {
        this.scrollToBottom();
        this.hideNewMessagesButton();
        this.pushEvent("scroll_to_bottom", {});
      });
      this.chatEl.parentElement.appendChild(btn);
    }
    btn.classList.add("new-messages-btn--visible");
  },

  hideNewMessagesButton() {
    if (!this.chatEl.parentElement) return;

    const btn = this.chatEl.parentElement.querySelector(".new-messages-btn");
    if (btn) {
      btn.classList.remove("new-messages-btn--visible");
    }
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
