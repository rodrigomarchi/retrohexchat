/**
 * LiveView hook for real-time character counter on chat input.
 * Updates counter text and applies warning/danger color classes.
 */
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
    const len = this.input.value.length;
    this.counter.textContent = len + "/" + this.maxLength;

    this.counter.classList.remove("char-counter--warning", "char-counter--danger");
    if (len > 900) {
      this.counter.classList.add("char-counter--danger");
    } else if (len > 450) {
      this.counter.classList.add("char-counter--warning");
    }
  },
};

export default CharCounterHook;
