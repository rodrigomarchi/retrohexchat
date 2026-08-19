/**
 * Signaling-recovery decisions for the persistent P2P session — pure.
 *
 * The hook owns the setTimeout timers, the live-pc state probes and the
 * pushEvent calls; the arithmetic that decides whether a retry may start, how
 * long to back off, whether a run is the last one, and whether a disconnect may
 * be deferred while media still moves is decided here against plain values, so
 * it can be tested without a connection. Mirrors lib/p2p/recovery.js, which does
 * the same for the conference.
 *
 * @module p2p/signaling_session
 */

/**
 * Whether a signal-replay run may start: no run pending and attempts remaining.
 * @param {number} attempts attempts already made
 * @param {number} max the ladder length
 * @param {boolean} hasTimer whether a replay is already scheduled
 * @returns {boolean}
 */
export function canScheduleSignalReplay(attempts, max, hasTimer) {
  return !hasTimer && attempts < max;
}

/**
 * The signal-replay backoff, growing with the (1-based) attempt number.
 * @param {number} attempt
 * @param {number} baseDelay
 * @returns {number}
 */
export function signalReplayDelay(attempt, baseDelay) {
  return baseDelay * attempt;
}

/**
 * Whether the connection still needs a signal replay: a live pc that is neither
 * connected nor ICE-completed, and recovery has not already given up.
 * @param {{hasPc: boolean, connectionState: string, iceConnectionState: string, recoveryFailed: boolean}} state
 * @returns {boolean}
 */
export function needsSignalReplay({ hasPc, connectionState, iceConnectionState, recoveryFailed }) {
  if (!hasPc || recoveryFailed) return false;
  return connectionState !== "connected" && iceConnectionState !== "completed";
}

/**
 * Whether a renegotiation retry may start: only the answerer asks the initiator
 * to renegotiate, and only with no run pending and attempts remaining.
 * @param {string} role
 * @param {number} attempts
 * @param {number} max
 * @param {boolean} hasTimer
 * @returns {boolean}
 */
export function canScheduleRenegotiationRetry(role, attempts, max, hasTimer) {
  return role === "answerer" && !hasTimer && attempts < max;
}

/**
 * The renegotiation-retry backoff, growing with the (1-based) attempt number.
 * @param {number} attempt
 * @param {number} baseDelay
 * @returns {number}
 */
export function renegotiationRetryDelay(attempt, baseDelay) {
  return baseDelay * attempt;
}

/**
 * Whether a retry run is the last the ladder allows (time to escalate).
 * @param {number} attempt
 * @param {number} max
 * @returns {boolean}
 */
export function isFinalRenegotiationAttempt(attempt, max) {
  return attempt >= max;
}

/**
 * Whether another activity-based deferral is allowed before forcing recovery of
 * a disconnected connection.
 * @param {number} deferrals
 * @param {number} limit
 * @returns {boolean}
 */
export function canDeferDisconnectedRecovery(deferrals, limit) {
  return deferrals < limit;
}
