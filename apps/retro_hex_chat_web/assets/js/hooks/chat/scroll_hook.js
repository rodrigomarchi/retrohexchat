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

const ScrollHook = {
  mounted() {
    this.chatEl = this.el;
    this.isAtBottom = true;
    this.pendingPrepend = false;
    this.prevScrollHeight = this.chatEl.scrollHeight;
    this.mouseDownPos = null;

    // Scroll to bottom on mount
    this.scrollToBottom();

    // Listen for scroll events
    this.chatEl.addEventListener("scroll", () => {
      this.handleScroll();
    });

    // Listen for new messages button click
    this.handleEvent("scroll_to_bottom", () => {
      this.scrollToBottom();
      this.hideNewMessagesButton();
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
        showFeedbackToast(this.el, "Copied!", 2000);
      });
    });

    // Copy selection handler (server → client)
    this.handleEvent("clipboard_copy_selection", () => {
      const selection = window.getSelection().toString();
      if (selection) {
        navigator.clipboard.writeText(selection).then(() => {
          showFeedbackToast(this.el, "Copied!", 2000);
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

    // Observe DOM mutations for auto-scroll and prepend handling
    this.observer = new MutationObserver(() => {
      if (this.pendingPrepend) {
        const newScrollHeight = this.chatEl.scrollHeight;
        const heightDiff = newScrollHeight - this.prevScrollHeight;
        this.chatEl.scrollTop += heightDiff;
        this.pendingPrepend = false;
      } else if (this.isAtBottom) {
        this.scrollToBottom();
      } else {
        this.showNewMessagesButton();
      }
    });

    this.observer.observe(this.chatEl, { childList: true, subtree: true });
  },

  updated() {
    if (this.isAtBottom) {
      this.scrollToBottom();
    }
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
    if (this._viewportLeaveHandler) {
      document.documentElement.removeEventListener("mouseleave", this._viewportLeaveHandler);
    }
    removeTooltip();
    cancelNickHoverTimer();
  },

  handleScroll() {
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

  showNewMessagesButton() {
    let btn = this.chatEl.parentElement.querySelector(".new-messages-btn");
    if (!btn) {
      btn = document.createElement("button");
      btn.className = "new-messages-btn";
      btn.textContent = "New messages";
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
};

export default ScrollHook;
