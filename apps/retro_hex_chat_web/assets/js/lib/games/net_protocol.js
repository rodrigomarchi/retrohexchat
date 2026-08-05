/**
 * Base wire format shared by every game, layered under each game's own
 * protocol module.
 *
 * The game channel is unreliable and unordered, so nothing here may depend on a
 * given datagram arriving. The two input transports are built to survive that:
 *
 * - `INPUT_STATE` is level-triggered. It carries the guest's *entire* input
 *   mask, resent every step. A lost datagram costs one step of staleness
 *   because the next one restates the same truth — no key can stick down.
 * - `INPUT_EDGE` is for games whose input is a discrete command rather than a
 *   held key. There is no later datagram restating it, so each command is sent
 *   redundantly and the host deduplicates on a sequence number.
 *
 * Game-specific message types live in the 0x80–0x84 range; the base reserves
 * 0x8E and above.
 *
 * @module games/net_protocol
 */

/** Base-level message types, disjoint from every game's own protocol. */
export const BASE_MSG = {
  INPUT_STATE: 0x8e,
  INPUT_EDGE: 0x8f,
};

const INPUT_STATE_SIZE = 5;
const INPUT_EDGE_SIZE = 4;

/** Sequence numbers are 16-bit and wrap; this is half the space. */
const SEQ_MODULO = 0x10000;

/**
 * Encode the guest's full input mask.
 * Layout: [type(1)][seq(2)][mask(2)]
 * @param {number} seq - Monotonic 16-bit sequence number.
 * @param {number} mask - Bitmask of held inputs.
 * @returns {ArrayBuffer}
 */
export function encodeInputState(seq, mask) {
  const buf = new ArrayBuffer(INPUT_STATE_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, BASE_MSG.INPUT_STATE);
  view.setUint16(1, seq % SEQ_MODULO, true);
  view.setUint16(3, mask & 0xffff, true);
  return buf;
}

/**
 * Decode an input mask datagram.
 * @param {ArrayBuffer} buf
 * @returns {{seq: number, mask: number}|null}
 */
export function decodeInputState(buf) {
  if (buf.byteLength < INPUT_STATE_SIZE) return null;
  const view = new DataView(buf);
  if (view.getUint8(0) !== BASE_MSG.INPUT_STATE) return null;
  return { seq: view.getUint16(1, true), mask: view.getUint16(3, true) };
}

/**
 * Encode a discrete input command.
 * Layout: [type(1)][seq(2)][code(1)]
 * @param {number} seq - Monotonic 16-bit sequence number.
 * @param {number} code - Game-defined command code.
 * @returns {ArrayBuffer}
 */
export function encodeInputEdge(seq, code) {
  const buf = new ArrayBuffer(INPUT_EDGE_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, BASE_MSG.INPUT_EDGE);
  view.setUint16(1, seq % SEQ_MODULO, true);
  view.setUint8(3, code & 0xff);
  return buf;
}

/**
 * Decode a discrete input command.
 * @param {ArrayBuffer} buf
 * @returns {{seq: number, code: number}|null}
 */
export function decodeInputEdge(buf) {
  if (buf.byteLength < INPUT_EDGE_SIZE) return null;
  const view = new DataView(buf);
  if (view.getUint8(0) !== BASE_MSG.INPUT_EDGE) return null;
  return { seq: view.getUint16(1, true), code: view.getUint8(3) };
}

/**
 * Whether `seq` is newer than `reference` across 16-bit wraparound.
 *
 * Unordered delivery means an older datagram can land after a newer one; naive
 * `>` would let it overwrite fresher input, and would also reject everything
 * after the counter wraps past 65535.
 *
 * @param {number} seq
 * @param {number|null} reference - Highest sequence accepted so far.
 * @returns {boolean}
 */
export function isNewerSeq(seq, reference) {
  if (reference === null || reference === undefined) return true;
  const delta = (seq - reference + SEQ_MODULO) % SEQ_MODULO;
  return delta !== 0 && delta < SEQ_MODULO / 2;
}

/**
 * Build the bitmask for a set of held inputs.
 * @param {Record<string, boolean>} inputs - Flat map of input name to held state.
 * @param {Record<string, number>} bits - Input name to bit position.
 * @returns {number}
 */
export function packInputs(inputs, bits) {
  let mask = 0;
  for (const name of Object.keys(bits)) {
    if (inputs[name]) mask |= 1 << bits[name];
  }
  return mask;
}

/**
 * Write a bitmask back into an input map, in place.
 * @param {number} mask
 * @param {Record<string, number>} bits - Input name to bit position.
 * @param {Record<string, boolean>} target - Map to populate.
 * @returns {Record<string, boolean>} the same `target`
 */
export function unpackInputs(mask, bits, target) {
  for (const name of Object.keys(bits)) {
    target[name] = (mask & (1 << bits[name])) !== 0;
  }
  return target;
}
