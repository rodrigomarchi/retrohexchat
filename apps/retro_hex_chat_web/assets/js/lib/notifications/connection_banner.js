export const DEBOUNCE_MS = 1000;
export const FADE_MS = 3000;

export function createBannerStateMachine() {
  let state = "hidden";
  let debounceTimer = null;
  let fadeTimer = null;
  let onChange = null;

  function setState(newState) {
    state = newState;
    if (onChange) onChange(state);
  }

  function clearTimers() {
    clearTimeout(debounceTimer);
    clearTimeout(fadeTimer);
    debounceTimer = null;
    fadeTimer = null;
  }

  return {
    wasConnected: false,

    getState() {
      return state;
    },

    setOnChange(fn) {
      onChange = fn;
    },

    onDisconnect() {
      if (!this.wasConnected) return;
      clearTimers();
      debounceTimer = setTimeout(() => {
        setState("disconnected");
      }, DEBOUNCE_MS);
    },

    onReconnect() {
      this.wasConnected = true;
      clearTimers();
      if (state === "disconnected") {
        setState("reconnected");
        fadeTimer = setTimeout(() => {
          setState("hidden");
        }, FADE_MS);
      } else {
        setState("hidden");
      }
    },

    onOverlayVisible() {
      clearTimers();
      setState("hidden");
    },

    destroy() {
      clearTimers();
      state = "hidden";
      onChange = null;
    },
  };
}
