/**
 * Binary protocol for Hex Tennis game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/hex_tennis/protocol
 */

import { schema, bool, custom, i16, u8, u16 } from "../core/codec.js";
import { MSG_TYPE, phases } from "../core/protocol_base.js";

export * from "../core/protocol_base.js";

/** The match's phases, by their value on the wire. */
export const PHASE = phases("SERVING", "RALLY", "POINT", "CHANGEOVER", "GAME_OVER");

// Game mode enum
export const GAME_MODE = {
  CLASSIC: 0,
  QUICK: 1,
  SUDDEN_DEATH: 2,
};

// Announcement enum
export const ANNOUNCEMENT = {
  NONE: 0,
  DEUCE: 1,
  ADV_P1: 2,
  ADV_P2: 3,
  GAME: 4,
  TIEBREAK: 5,
};

// Out type enum
export const OUT_TYPE = {
  NONE: 0,
  WIDE: 1,
  LONG: 2,
  ACE: 3,
  DEAD: 4,
};

const SERVE_FLAGS = [
  "isTiebreak",
  "hitEvent",
  "serveEvent",
  "netFault",
  "outOfBounds",
  "faultEvent",
  "isSecondServe",
];

/** Who serves (bit 0: player 2) and the rally's seven event flags, in one byte. */
const serveFlags = custom({
  spec: { kind: "custom", names: ["server", ...SERVE_FLAGS] },
  size: () => 1,
  write(view, offset, s) {
    let flags = s.server === 2 ? 1 : 0;
    SERVE_FLAGS.forEach((name, i) => {
      if (s[name]) flags |= 2 << i;
    });
    view.setUint8(offset, flags);
    return offset + 1;
  },
  read(view, offset, out) {
    if (offset + 1 > view.byteLength) return -1;
    const flags = view.getUint8(offset);
    out.server = flags & 1 ? 2 : 1;
    SERVE_FLAGS.forEach((name, i) => {
      out[name] = (flags & (2 << i)) !== 0;
    });
    return offset + 1;
  },
});

/** The host's snapshot of the court, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  u16("p1x", { round: true }),
  u16("p1y", { round: true }),
  u16("p2x", { round: true }),
  u16("p2y", { round: true }),
  u16("ballX", { clamp: [0, Infinity], scale: 10 }),
  u16("ballY", { clamp: [0, Infinity], scale: 10 }),
  i16("ballVX", { scale: 100 }),
  i16("ballVY", { scale: 100 }),
  u8("ballHeight", { clamp: [0, 1], scale: 255 }),
  u8("p1Points"),
  u8("p2Points"),
  u8("p1Games"),
  u8("p2Games"),
  u8("phase"),
  u8("countdown"),
  serveFlags,
  u8("outType"),
  u8("pointWinner"),
  u8("announcement"),
  u8("lastHitter"),
  u8("rallyCount", { clamp: [-Infinity, 255] }),
  u8("gameMode"),
  u8("serveTimer", { encode: (t) => Math.min(255, t >> 2), decode: (raw) => raw << 2 }),
]);

/** How the match ended. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [
  u8("p1Games"),
  u8("p2Games"),
  u8("winner"),
  u8("gameMode"),
  bool("wasTiebreak"),
]);
