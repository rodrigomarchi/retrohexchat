const sink = globalThis["console"];

export const log = Object.freeze({
  debug(...args) {
    sink?.debug?.(...args);
  },

  error(...args) {
    sink?.error?.(...args);
  },

  warn(...args) {
    sink?.warn?.(...args);
  },
});
