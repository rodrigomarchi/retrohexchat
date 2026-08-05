import { encodeInputState, packInputs } from "../../js/lib/games/net_protocol.js";

/**
 * Build the input datagram a guest would send for a given set of held keys.
 *
 * Input is level-triggered: one datagram states the guest's *entire* input, so
 * anything not named here is released. That is the property under test as much
 * as the pressed keys are — it is what makes a lost datagram cost a step of
 * staleness rather than a stuck key.
 *
 * @param {typeof import("../../js/lib/game_engine.js").GameEngine} EngineClass
 * @param {Record<string, boolean>} held
 * @param {number} [seq] - Sequence number; must rise across a test's datagrams.
 * @returns {ArrayBuffer}
 */
export function inputDatagram(EngineClass, held, seq = 1) {
  return encodeInputState(seq, packInputs(held, EngineClass.INPUT_BITS));
}

/**
 * The bitmask a given set of held keys produces for a game.
 *
 * @param {typeof import("../../js/lib/game_engine.js").GameEngine} EngineClass
 * @param {Record<string, boolean>} held
 * @returns {number}
 */
export function inputMask(EngineClass, held) {
  return packInputs(held, EngineClass.INPUT_BITS);
}

/**
 * A sender that keeps its own rising sequence, for tests that send more than
 * one datagram. The host drops anything that is not newer than what it has.
 *
 * @param {typeof import("../../js/lib/game_engine.js").GameEngine} EngineClass
 * @returns {(held: Record<string, boolean>) => ArrayBuffer}
 */
export function inputSender(EngineClass) {
  let seq = 0;
  return (held) => {
    seq += 1;
    return inputDatagram(EngineClass, held, seq);
  };
}
