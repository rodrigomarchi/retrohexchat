/**
 * LiveView hook for infinite scroll and auto-scroll in chat messages.
 *
 * - Detects scroll-to-top and pushes "load_more" event
 * - Auto-scrolls to bottom when at bottom and new message arrives
 * - Shows "New messages" button when scrolled up and new message arrives
 * - Preserves scroll position during prepend of older messages
 */
import {
  isAtBottom as checkIsAtBottom,
  shouldLoadMore,
  detectContextTarget,
  buildMessageText,
  collectUrls,
} from "../lib/chat.js";

const ScrollHook = {
  mounted() {
    this.chatEl = this.el;
    this.isAtBottom = true;
    this.pendingPrepend = false;
    this.prevScrollHeight = this.chatEl.scrollHeight;

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

    // Listen for file download (log export)
    this.handleEvent("download_file", ({ content, filename, mime_type }) => {
      const bytes = Uint8Array.from(atob(content), (c) => c.charCodeAt(0));
      const blob = new Blob([bytes], { type: mime_type });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    });

    // Double-click on channel names in chat → join/switch channel
    this.chatEl.addEventListener("dblclick", (e) => {
      const channelEl = e.target.closest(".chat-channel-link");
      if (channelEl) {
        const channel = channelEl.dataset.channel;
        if (channel) {
          this.pushEvent("channel_dblclick", { channel });
        }
      }
    });

    // Smart right-click context menu detection
    this.chatEl.addEventListener("contextmenu", (e) => {
      if (e.target.closest("textarea, input, [contenteditable]")) return;

      const msgEl = e.target.closest(".chat-message");
      if (!msgEl) return;

      e.preventDefault();
      this.detectAndPushContextMenu(e, msgEl);
    });

    // Clipboard copy handler (server → client)
    this.handleEvent("clipboard_copy", ({ text }) => {
      navigator.clipboard.writeText(text);
    });

    // Copy selection handler (server → client)
    this.handleEvent("clipboard_copy_selection", () => {
      const selection = window.getSelection().toString();
      if (selection) {
        navigator.clipboard.writeText(selection);
      }
    });

    // Open URL handler (server → client)
    this.handleEvent("open_url", ({ url }) => {
      window.open(url, "_blank", "noopener,noreferrer");
    });

    // Listen for prepend start (before DOM update)
    this.handleEvent("prepend_start", () => {
      this.pendingPrepend = true;
      this.prevScrollHeight = this.chatEl.scrollHeight;
    });

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
    btn.style.display = "block";
  },

  hideNewMessagesButton() {
    const btn = this.chatEl.parentElement.querySelector(".new-messages-btn");
    if (btn) {
      btn.style.display = "none";
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
