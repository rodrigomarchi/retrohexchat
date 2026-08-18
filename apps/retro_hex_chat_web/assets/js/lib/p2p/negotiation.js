/**
 * The single-offerer negotiation rules, shared by the P2P session and the
 * conference — pure decisions over (role, signalingState, epoch), no DOM.
 *
 * The lobby and the group call each resolved offer/answer glare on their own;
 * these are the rules the lobby ran, lifted out so both can share one tested
 * copy. The effects — logging an ignored description, mutating the epoch —
 * stay in the hooks; only the decisions live here.
 *
 * @module p2p/negotiation
 */

/**
 * Whether this peer is the one responsible for applying a description of the
 * given type. Unknown until the LiveView assigns a role, and until then nothing
 * is filtered out: the initiator's offer routinely beats the answer signal.
 *
 * @param {"initiator"|"answerer"|null|undefined} role
 * @param {"offer"|"answer"} type
 * @returns {boolean}
 */
export function ownsDescription(role, type) {
  if (!role) return true;
  return role === "initiator" ? type === "answer" : type === "offer";
}

/**
 * Whether a connection in `signalingState` can accept a description of `type`.
 * setRemoteDescription throws otherwise, and the catch escalates a stray
 * description into a full rebuild — so it is screened here first.
 *
 * @param {string} signalingState
 * @param {"offer"|"answer"} type
 * @returns {boolean}
 */
export function canApplyDescription(signalingState, type) {
  return type === "offer"
    ? signalingState === "stable" || signalingState === "have-remote-offer"
    : signalingState === "have-local-offer";
}

/**
 * A positive integer epoch, or null when the value is not one.
 *
 * @param {unknown} value
 * @returns {number|null}
 */
export function normalizeEpoch(value) {
  const number = Number(value);
  return Number.isInteger(number) && number > 0 ? number : null;
}

/**
 * The epoch a fresh connection should adopt: the requested one when it is at
 * least the current epoch, otherwise one past the current.
 *
 * @param {number} current
 * @param {unknown} requested
 * @returns {number}
 */
export function nextConnectionEpoch(current, requested) {
  const normalized = normalizeEpoch(requested);
  if (normalized && normalized >= current) return normalized;
  return current + 1;
}

/**
 * The epoch after advancing: the requested one when it is strictly greater than
 * the current, otherwise the current plus one.
 *
 * @param {number} current
 * @param {unknown} requested
 * @returns {number}
 */
export function advanceEpoch(current, requested) {
  const normalized = normalizeEpoch(requested);
  return normalized && normalized > current ? normalized : current + 1;
}

/**
 * Whether an incoming epoch is older than the current one and should be dropped.
 *
 * @param {number} current
 * @param {unknown} epoch
 * @returns {boolean}
 */
export function isStaleEpoch(current, epoch) {
  return !!epoch && current > 0 && epoch < current;
}
