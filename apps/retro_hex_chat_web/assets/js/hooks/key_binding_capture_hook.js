/**
 * KeyBindingCaptureHook — captures keydown events for key binding reassignment.
 *
 * When a keybinding row is selected for editing, the server pushes a
 * "start_key_capture" event. This hook sets up a one-time keydown listener
 * that captures the key + modifiers and sends them back to the server
 * via "options_capture_key" push event.
 */
const KeyBindingCaptureHook = {
  mounted() {
    this.captureHandler = null;

    this.handleEvent("start_key_capture", ({ action }) => {
      this.startCapture(action);
    });

    this.handleEvent("stop_key_capture", () => {
      this.stopCapture();
    });
  },

  destroyed() {
    this.stopCapture();
  },

  startCapture(action) {
    this.stopCapture();

    this.captureHandler = (e) => {
      // Ignore standalone modifier keys
      if (["Control", "Alt", "Shift", "Meta"].includes(e.key)) return;

      e.preventDefault();
      e.stopPropagation();

      this.pushEvent("options_capture_key", {
        action: action,
        key: e.key,
        ctrlKey: e.ctrlKey,
        altKey: e.altKey,
        shiftKey: e.shiftKey
      });

      this.stopCapture();
    };

    document.addEventListener("keydown", this.captureHandler, true);
  },

  stopCapture() {
    if (this.captureHandler) {
      document.removeEventListener("keydown", this.captureHandler, true);
      this.captureHandler = null;
    }
  }
};

export default KeyBindingCaptureHook;
