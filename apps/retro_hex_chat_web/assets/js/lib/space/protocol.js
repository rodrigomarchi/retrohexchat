/**
 * Virtual-space wire protocol: event-name constants, versioning and payload
 * normalization. The server (Elixir) is authoritative; this module only
 * defends the client against missing/renamed fields and coerces types so the
 * engine never has to null-check raw channel payloads.
 * @module space/protocol
 */

export const PROTOCOL_VERSION = 1;

/** Client → server event names (channel pushes). */
export const CLIENT_EVENTS = Object.freeze({
  INPUT: "space_input",
  STOP: "space_stop",
  INTERACT: "space_interact",
  CHAT_BUBBLE: "space_chat_bubble",
  ADMIN_ACTION: "space_admin_action",
  LEAVE: "space_leave",
});

/** Server → client event names (channel events). */
export const SERVER_EVENTS = Object.freeze({
  SNAPSHOT: "space_snapshot",
  DELTA: "space_delta",
  RECONCILE: "space_reconcile",
  MESSAGE: "space_message",
  MODAL: "space_modal",
  MAP_CHANGED: "space_map_changed",
  KICKED: "space_participant_kicked",
  ADMIN_NOTICE: "space_admin_notice",
  CLOSED: "space_closed",
});

const DIRECTIONS = new Set(["up", "down", "left", "right"]);
const POSES = new Set(["standing", "sitting"]);

/**
 * Normalize a single participant record into a fully-populated object.
 * @param {string} key participant key (e.g. "registered:1")
 * @param {object} raw raw participant payload
 * @returns {object}
 */
export function normalizeParticipant(key, raw = {}) {
  return {
    key,
    nickname: typeof raw.nickname === "string" ? raw.nickname : "",
    avatar: typeof raw.avatar === "string" ? raw.avatar : "default",
    x: toInt(raw.x, 0),
    y: toInt(raw.y, 0),
    dir: DIRECTIONS.has(raw.dir) ? raw.dir : "down",
    pose: POSES.has(raw.pose) ? raw.pose : "standing",
    moving: raw.moving === true,
    online: raw.online !== false,
    muted: raw.muted === true,
    seatId: raw.seat_id ?? raw.seatId ?? null,
    zoneId: raw.zone_id ?? raw.zoneId ?? null,
  };
}

/**
 * Normalize the `space_init` join reply.
 * @param {object} raw
 * @returns {object}
 */
export function normalizeSpaceInit(raw = {}) {
  if (isPresent(raw.version) && raw.version !== PROTOCOL_VERSION) {
    console.error(
      `[space] unknown protocol version ${raw.version} (expected ${PROTOCOL_VERSION}); ` +
        "attempting best-effort decode",
    );
  }

  return {
    channelName: raw.channel_name ?? raw.channelName ?? raw.token ?? null,
    selfKey: raw.self_key ?? raw.selfKey ?? null,
    map: raw.map && typeof raw.map === "object" ? raw.map : {},
    config: raw.config && typeof raw.config === "object" ? raw.config : {},
    snapshot: normalizeSnapshot(raw.snapshot),
  };
}

/**
 * Normalize a full `space_snapshot`.
 * @param {object} raw
 * @returns {{serverTime: number|null, participants: object}}
 */
export function normalizeSnapshot(raw = {}) {
  return {
    serverTime: raw.server_time ?? raw.serverTime ?? null,
    participants: normalizeParticipants(raw.participants),
  };
}

/**
 * Normalize an incremental `space_delta`.
 * @param {object} raw
 * @returns {object}
 */
export function normalizeDelta(raw = {}) {
  return {
    serverTime: raw.server_time ?? raw.serverTime ?? null,
    seqAck: isObject(raw.seq_ack) ? raw.seq_ack : isObject(raw.seqAck) ? raw.seqAck : {},
    updates: normalizeUpdates(raw.updates),
    joined: normalizeParticipants(raw.joined),
    left: Array.isArray(raw.left) ? raw.left : [],
  };
}

function normalizeParticipants(rawParticipants) {
  if (!isObject(rawParticipants)) return {};

  const out = {};
  for (const [key, value] of Object.entries(rawParticipants)) {
    out[key] = normalizeParticipant(key, value ?? {});
  }
  return out;
}

// Delta updates are partial (position/dir only), so they keep raw fields but
// still coerce coordinates and clamp direction.
function normalizeUpdates(rawUpdates) {
  if (!isObject(rawUpdates)) return {};

  const out = {};
  for (const [key, value] of Object.entries(rawUpdates)) {
    const update = value ?? {};
    out[key] = {
      ...update,
      ...(isPresent(update.x) ? { x: toInt(update.x, 0) } : {}),
      ...(isPresent(update.y) ? { y: toInt(update.y, 0) } : {}),
      ...(isPresent(update.dir) ? { dir: DIRECTIONS.has(update.dir) ? update.dir : "down" } : {}),
      ...(isPresent(update.moving) ? { moving: update.moving === true } : {}),
    };
  }
  return out;
}

function toInt(value, fallback) {
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) ? n : fallback;
}

function isObject(value) {
  return isPresent(value) && typeof value === "object" && !Array.isArray(value);
}

function isPresent(value) {
  return value !== undefined && value !== null;
}
