/**
 * @file Always-safe facade over the Grafana Faro RUM API.
 *
 * Faro arrives late by design: `faro_gate.js` only imports the SDK once the
 * page has gone idle, and on a page with RUM disabled it never arrives at all.
 * Call sites must not care. Every function here resolves the SDK at call time
 * and does nothing when it is absent, so instrumentation reads as one line at
 * the point being measured instead of a readiness dance around it.
 *
 * The SDK is reached through the global the Faro bootstrap publishes rather
 * than through an import, because importing it here would drag those 262 KB
 * back into the app bundle — the exact cost the gate exists to avoid.
 */
import { log } from "../logger.js";

/**
 * Resolve the Faro API, or null while RUM is absent.
 *
 * @returns {object | null} The `faro.api` object, or null.
 */
function api() {
  return globalThis.faro?.api ?? null;
}

/**
 * Report a numeric measurement to RUM.
 *
 * Silently does nothing until the SDK has booted — a dropped measurement is the
 * correct outcome on a page that ships no telemetry.
 *
 * @param {string} type - Measurement type, snake_case (e.g. "liveview_lag").
 * @param {Record<string, number>} values - Named numeric values.
 * @param {Record<string, string>} [context] - Optional low-cardinality context.
 * @returns {boolean} Whether the measurement was handed to the SDK.
 */
export function recordMeasurement(type, values, context) {
  const faroApi = api();
  if (!faroApi?.pushMeasurement) return false;

  try {
    faroApi.pushMeasurement({ type, values }, context ? { context } : undefined);
    return true;
  } catch (error) {
    log.warn("[rum] measurement dropped", type, error);
    return false;
  }
}

/**
 * The Faro session this browser is recording under.
 *
 * The chat rides a websocket, so no request header ever carries this to the
 * server; something has to hand it over explicitly for the two sides to be
 * readable together. Null until the SDK has booted.
 *
 * @returns {string | null} The session id, or null.
 */
export function sessionId() {
  try {
    return api()?.getSession?.()?.id ?? null;
  } catch (error) {
    log.warn("[rum] session id unavailable", error);
    return null;
  }
}

/**
 * Report a named event to RUM.
 *
 * @param {string} name - Event name, snake_case (e.g. "liveview_socket_lost").
 * @param {Record<string, string>} [attributes] - Optional string attributes.
 * @param {string} [domain] - Optional grouping domain.
 * @returns {boolean} Whether the event was handed to the SDK.
 */
export function recordEvent(name, attributes, domain) {
  const faroApi = api();
  if (!faroApi?.pushEvent) return false;

  try {
    faroApi.pushEvent(name, attributes, domain);
    return true;
  } catch (error) {
    log.warn("[rum] event dropped", name, error);
    return false;
  }
}
