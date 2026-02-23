import {
  scrollToMessage,
  highlightEditingMessage,
  removeEditingHighlight,
} from "../lib/message_interactions";

/**
 * Hook for message interactions: scroll-to-message, edit mode DOM wiring,
 * and hover reply button.
 *
 * Attached to the #chat-messages container.
 */
const MessageInteractionsHook = {
  mounted() {
    this.handleEvent("scroll_to_message", ({ message_id }) => {
      scrollToMessage(message_id);
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

    // Hover reply button
    this.el.addEventListener("mouseenter", this._onMouseEnter.bind(this), true);
    this.el.addEventListener("mouseleave", this._onMouseLeave.bind(this), true);
  },

  destroyed() {
    this.el.removeEventListener("mouseenter", this._onMouseEnter, true);
    this.el.removeEventListener("mouseleave", this._onMouseLeave, true);
  },

  _onMouseEnter(e) {
    const msgEl = e.target.closest(".chat-message--message");
    if (!msgEl || msgEl.querySelector(".chat-reply-btn")) return;

    const btn = document.createElement("button");
    btn.className = "chat-reply-btn";
    btn.textContent = "\u21A9";
    btn.title = "Responder";
    btn.setAttribute("tabindex", "0");

    btn.addEventListener("click", (ev) => {
      ev.stopPropagation();
      const messageId = msgEl.id.replace("msg-", "").replace(/^chat_messages-/, "");
      this.pushEvent("reply_to_message", { message_id: messageId });
    });

    msgEl.appendChild(btn);
  },

  _onMouseLeave(e) {
    const msgEl = e.target.closest(".chat-message--message");
    if (!msgEl) return;
    const btn = msgEl.querySelector(".chat-reply-btn");
    if (btn) btn.remove();
  },
};

export default MessageInteractionsHook;
