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
};

export default ScrollHook;
