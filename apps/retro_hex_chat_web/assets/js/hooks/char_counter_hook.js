/**
 * LiveView hook for real-time character counter on chat input.
 * Updates counter text and applies warning/danger color classes.
 */
import { getCounterState } from "../lib/counter.js";

const SEVERITY_CLASSES = {
  warning: "char-counter--warning",
  danger: "char-counter--danger",
};

const CharCounterHook = {
  mounted() {
    this.input = this.el.querySelector("#chat-input");
    this.counter = this.el.querySelector("[data-testid='char-counter']");
    if (!this.input || !this.counter) return;

    this.maxLength = 1000;
    this.updateCounter();

    this.input.addEventListener("input", () => this.updateCounter());
  },

  updated() {
    if (this.input && this.counter) {
      this.updateCounter();
    }
  },

  updateCounter() {
    const { text, severity } = getCounterState(this.input.value.length, this.maxLength);

    this.counter.textContent = text;
    this.counter.classList.remove(SEVERITY_CLASSES.warning, SEVERITY_CLASSES.danger);
    if (severity !== "normal") {
      this.counter.classList.add(SEVERITY_CLASSES[severity]);
    }
  },
};

export default CharCounterHook;
