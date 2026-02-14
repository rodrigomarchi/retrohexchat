/**
 * LiveView hook for infinite scroll and auto-scroll in chat messages.
 *
 * - Detects scroll-to-top and pushes "load_more" event
 * - Auto-scrolls to bottom when at bottom and new message arrives
 * - Shows "New messages" button when scrolled up and new message arrives
 * - Preserves scroll position during prepend of older messages
 */
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
        if (!link.nextElementSibling || !link.nextElementSibling.classList.contains("chat-link-preview")) {
          const preview = document.createElement("span");
          preview.className = "chat-link-preview";
          preview.textContent = title;
          link.after(preview);
        }
      });
    });

    // Listen for file download (log export)
    this.handleEvent("download_file", ({ content, filename, mime_type }) => {
      const bytes = Uint8Array.from(atob(content), c => c.charCodeAt(0));
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
      // Skip if inside input field — preserve browser default menu
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
        // Preserve scroll position after prepend
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
    // After LiveView DOM patch, check if we should scroll
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
    const { scrollTop, scrollHeight, clientHeight } = this.chatEl;

    // Check if at bottom (within 50px threshold)
    this.isAtBottom = scrollHeight - scrollTop - clientHeight < 50;

    if (this.isAtBottom) {
      this.hideNewMessagesButton();
    }

    // Check if at top (within 10px threshold) - trigger load more
    if (scrollTop < 10) {
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

  /**
   * Detect what was right-clicked and push context menu event.
   * Priority: nick > URL > channel > message (most specific wins).
   */
  detectAndPushContextMenu(e, msgEl) {
    const target = e.target;
    const payload = {
      x: e.clientX,
      y: e.clientY,
      author: msgEl.dataset.author || "",
      message_id: msgEl.dataset.messageId || "",
      is_system: msgEl.dataset.systemMessage === "true",
      has_selection: window.getSelection().toString().length > 0,
      message_text: this.buildMessageText(msgEl),
      message_urls: this.collectUrls(msgEl),
    };

    // Check nick first (most specific)
    const nickEl = target.closest(".chat-nick[data-nick]");
    if (nickEl) {
      payload.type = "nick";
      payload.nick = nickEl.dataset.nick;
      this.pushEvent("chat_context_menu", payload);
      return;
    }

    // Check URL
    const urlEl = target.closest(".chat-link[data-url]");
    if (urlEl) {
      payload.type = "url";
      payload.url = urlEl.dataset.url;
      this.pushEvent("chat_context_menu", payload);
      return;
    }

    // Check channel link
    const channelEl = target.closest(".chat-channel-link[data-channel]");
    if (channelEl) {
      payload.type = "channel";
      payload.channel = channelEl.dataset.channel;
      this.pushEvent("chat_context_menu", payload);
      return;
    }

    // Default: message context menu
    payload.type = "message";
    if (payload.message_urls.length > 0) {
      payload.url = payload.message_urls[0];
    }
    this.pushEvent("chat_context_menu", payload);
  },

  /**
   * Build formatted message text for "Copy Message": [HH:MM] <Nick> message
   */
  buildMessageText(msgEl) {
    const timestampEl = msgEl.querySelector(".chat-timestamp");
    const nickEl = msgEl.querySelector(".chat-nick");
    const contentEl = msgEl.querySelector(".chat-content");

    if (timestampEl && nickEl && contentEl) {
      const time = timestampEl.textContent.trim();
      const nick = (msgEl.dataset.author || "").trim();
      const content = contentEl.textContent.trim();
      return `[${time}] <${nick}> ${content}`;
    }

    // Fallback for non-standard messages (action, system, etc.)
    return msgEl.textContent.trim().replace(/\s+/g, " ");
  },

  /**
   * Collect all URLs from data-url attributes in a message.
   */
  collectUrls(msgEl) {
    return Array.from(msgEl.querySelectorAll(".chat-link[data-url]")).map(
      (el) => el.dataset.url
    );
  },
};

export default ScrollHook;
