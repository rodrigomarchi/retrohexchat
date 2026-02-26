/**
 * Unified connection state machine.
 *
 * Pure logic — no DOM or LiveView dependencies.
 * States: connecting, connected, disconnected, reconnecting, reconnected, cancelled, failed.
 */

export const DEFAULTS = {
  maxAttempts: 10,
  maxDelay: 30,
  bannerDebounceMs: 1000,
  bannerToOverlayMs: 2000,
  reconnectedFadeMs: 3000,
};

/**
 * Calculate exponential backoff delay.
 *
 * @param {number} attempt - Current attempt number (1-based)
 * @param {number} [maxDelay=30] - Maximum delay in seconds
 * @returns {number} Delay in seconds
 */
export function getBackoffDelay(attempt, maxDelay = DEFAULTS.maxDelay) {
  return Math.min(Math.pow(2, attempt - 1), maxDelay);
}

/**
 * @typedef {Object} ConnectionCallbacks
 * @property {function(string, Object=): void} onStateChange - Called on every state transition
 * @property {function(): void} onMaxAttemptsExceeded - Called when reconnection fails permanently
 */

/**
 * Create a connection state machine.
 *
 * @param {ConnectionCallbacks} callbacks
 * @param {Object} [opts] - Override DEFAULTS
 * @returns {Object} State machine API
 */
export function createConnectionStateMachine(callbacks, opts = {}) {
  const config = { ...DEFAULTS, ...opts };
  let state = "connecting";
  let attempt = 0;
  let countdownRemaining = 0;
  const timers = { debounce: null, escalate: null, countdown: null, fade: null };

  function clearAllTimers() {
    for (const key of Object.keys(timers)) {
      if (timers[key] !== null) {
        clearTimeout(timers[key]);
        clearInterval(timers[key]);
        timers[key] = null;
      }
    }
  }

  function setState(newState, data) {
    state = newState;
    callbacks.onStateChange(newState, data);
  }

  function startCountdown() {
    timers.countdown = setInterval(() => {
      countdownRemaining--;
      if (countdownRemaining <= 0) {
        clearInterval(timers.countdown);
        timers.countdown = null;
        attempt++;
        if (attempt > config.maxAttempts) {
          setState("failed");
          callbacks.onMaxAttemptsExceeded();
          return;
        }
        countdownRemaining = getBackoffDelay(attempt, config.maxDelay);
        setState("reconnecting", {
          attempt,
          maxAttempts: config.maxAttempts,
          remaining: countdownRemaining,
        });
        startCountdown();
      } else {
        callbacks.onStateChange("reconnecting", {
          attempt,
          maxAttempts: config.maxAttempts,
          remaining: countdownRemaining,
        });
      }
    }, 1000);
  }

  return {
    getState() {
      return state;
    },

    onMounted() {
      setState("connected");
    },

    onDisconnect() {
      if (state === "connecting") return;
      clearAllTimers();
      attempt = 0;

      timers.debounce = setTimeout(() => {
        setState("disconnected");

        timers.escalate = setTimeout(() => {
          attempt = 1;
          countdownRemaining = getBackoffDelay(attempt, config.maxDelay);
          setState("reconnecting", {
            attempt,
            maxAttempts: config.maxAttempts,
            remaining: countdownRemaining,
          });
          startCountdown();
        }, config.bannerToOverlayMs);
      }, config.bannerDebounceMs);
    },

    onReconnect() {
      const wasDisconnected = state === "disconnected" || state === "reconnecting";
      clearAllTimers();
      attempt = 0;

      if (wasDisconnected) {
        setState("reconnected");
        timers.fade = setTimeout(() => setState("connected"), config.reconnectedFadeMs);
      } else {
        setState("connected");
      }
    },

    cancel() {
      if (state !== "reconnecting") return;
      clearAllTimers();
      setState("cancelled");
    },

    destroy() {
      clearAllTimers();
    },
  };
}
