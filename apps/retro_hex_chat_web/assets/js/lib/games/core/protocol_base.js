/**
 * What every game's protocol module carries besides its own messages: the
 * message-type table (the 0x80+ range shared with game_engine.js), the
 * readiness ping and reading a message's type. A protocol re-exports this
 * whole module, so its callers keep importing everything from the one place.
 * @module games/core/protocol_base
 */

export { GAME_MSG as MSG_TYPE } from "./messages.js";
export { encodeGameReady, getMessageType } from "../net_protocol.js";
