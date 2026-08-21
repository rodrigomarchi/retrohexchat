/**
 * @file The one console sink, with arguments RUM can actually read.
 *
 * Faro's console instrumentation stringifies whatever it is handed, so an
 * object argument reached Grafana as the literal text `[object Object]` — which
 * is how `[space] channel join rejected` arrived carrying no reason at all.
 * Objects are therefore serialised here, once, for every call site.
 *
 * `Error` values are passed through untouched: Faro reads their stack, and the
 * source-map deobfuscation on the collector depends on it.
 */

/** Cap per serialised argument, so one fat payload cannot flood the beacon. */
const MAX_SERIALIZED_CHARS = 1000;

/**
 * Render one console argument as something a log line can carry.
 *
 * @param {unknown} value - The argument as the call site passed it.
 * @returns {unknown} The value itself, or a serialised stand-in.
 */
function readable(value) {
  if (value === null || typeof value !== "object") return value;
  if (value instanceof Error) return value;

  const seen = new WeakSet();

  try {
    const json = JSON.stringify(value, (_key, nested) => {
      if (nested === null || typeof nested !== "object") return nested;
      if (seen.has(nested)) return "[circular]";
      seen.add(nested);
      return nested;
    });

    if (json === undefined) return String(value);

    return json.length > MAX_SERIALIZED_CHARS ? `${json.slice(0, MAX_SERIALIZED_CHARS)}…` : json;
  } catch {
    // A getter that throws, a Proxy that refuses inspection: the point is to
    // say something rather than lose the argument.
    return String(value);
  }
}

const sink = globalThis["console"];

export const log = Object.freeze({
  debug(...args) {
    sink?.debug?.(...args.map(readable));
  },

  error(...args) {
    sink?.error?.(...args.map(readable));
  },

  warn(...args) {
    sink?.warn?.(...args.map(readable));
  },
});
