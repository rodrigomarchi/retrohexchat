/**
 * Sends focus back to the chat composer when its element is clicked.
 *
 * Lives in the About dialog, which the showcase renders too — so both the app
 * and the showcase bundle register it. Where there is no composer the lookup
 * simply finds nothing and the hook stays inert.
 */
const FocusChatInputOnClickHook = {
  mounted() {
    this._onClick = () => {
      setTimeout(() => document.getElementById("chat-input")?.focus(), 150);
    };
    this.el.addEventListener("click", this._onClick);
  },

  destroyed() {
    this.el.removeEventListener("click", this._onClick);
  },
};

export default FocusChatInputOnClickHook;
