/**
 * LiveView hook for real-time character counter on chat input.
 *
 * Updates counter text and applies warning/danger color classes, AND
 * keeps the Send button's disabled state in sync with the textarea
 * content. The server-side disabled={@char_count == 0} is correct on
 * initial render (@input starts empty), but @input is only updated on
 * submit — without phx-change there's no per-keystroke server roundtrip.
 * So we mirror the textarea's actual length client-side here.
 */
import { getCounterState } from "../../lib/ui/counter.js";

const CharCounterHook = {
  mounted() {
    this.input = this.el.querySelector("#chat-input");
    this.counter = this.el.querySelector("[data-testid='char-counter']");
    this.sendButton = this.el.querySelector("[data-testid='chat-input-send']");
    if (!this.input || !this.counter) return;

    this.maxLength = 1000;
    this.refresh();

    this.input.addEventListener("input", () => this.refresh());
  },

  updated() {
    if (this.input && this.counter) {
      this.refresh();
    }
  },

  refresh() {
    this.updateCounter();
    this.updateSendButton();
  },

  updateCounter() {
    const { text, severity } = getCounterState(this.input.value.length, this.maxLength);

    this.counter.textContent = text;
    this.counter.classList.toggle("char-counter--warning", severity === "warning");
    this.counter.classList.toggle("char-counter--danger", severity === "danger");
  },

  updateSendButton() {
    if (!this.sendButton) return;
    // The textarea reflects the user's actual typed content; mirror that
    // into the disabled attribute so the button is clickable as soon as
    // there is something to send. A pending attachment is something to send
    // on its own, which only the server knows — it says so on the button.
    // LiveView re-renders that reset @input back to "" will call updated()
    // and we'll re-disable correctly.
    const canSendEmpty = this.sendButton.dataset.canSendEmpty === "true";
    this.sendButton.disabled = this.input.value.length === 0 && !canSendEmpty;
  },
};

export default CharCounterHook;
