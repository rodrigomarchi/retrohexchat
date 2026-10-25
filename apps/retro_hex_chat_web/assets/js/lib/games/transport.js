/**
 * Transport contracts for browser game engines.
 *
 * P2P matches use a real RTCDataChannel. Solo matches run in-process and need a
 * transport object that has the same shape without pretending to be WebRTC.
 *
 * @module games/transport
 */

/** @returns {boolean} */
export function isGameTransport(value) {
  return (
    !!value &&
    typeof value.kind === "string" &&
    typeof value.addEventListener === "function" &&
    typeof value.removeEventListener === "function" &&
    typeof value.send === "function"
  );
}

/**
 * Wrap a DataChannel in the game transport contract.
 *
 * @param {RTCDataChannel} channel
 * @returns {object}
 */
export function createDataChannelTransport(channel) {
  return {
    kind: "p2p",
    raw: channel,

    get readyState() {
      return channel?.readyState || "closed";
    },

    get telemetryState() {
      return channel?.readyState || "unknown";
    },

    get bufferedAmount() {
      return channel?.bufferedAmount || 0;
    },

    addEventListener(type, listener) {
      channel.addEventListener(type, listener);
    },

    removeEventListener(type, listener) {
      channel.removeEventListener(type, listener);
    },

    send(data) {
      channel.send(data);
      return true;
    },
  };
}

/**
 * The add/remove half of an event target, over `listeners` (type → Set).
 * @param {Map<string, Set<Function>>} listeners
 */
function subscriptions(listeners) {
  return {
    addEventListener(type, listener) {
      if (!listeners.has(type)) listeners.set(type, new Set());
      listeners.get(type).add(listener);
    },

    removeEventListener(type, listener) {
      listeners.get(type)?.delete(listener);
    },
  };
}

/**
 * Create a local in-process transport for solo game runtimes.
 *
 * @returns {object}
 */
export function createLocalTransport() {
  const listeners = new Map();

  return {
    kind: "local",
    readyState: "open",
    telemetryState: "local",
    bufferedAmount: 0,

    ...subscriptions(listeners),

    send() {
      return true;
    },
  };
}

/**
 * Create the transport a spectator's engine reads a match from.
 *
 * The host's snapshots arrive through the server rather than a DataChannel,
 * and `deliver()` hands each one to the engine as the DataChannel would. A
 * spectator never speaks: the transport is never "open", so the engine's own
 * guard drops its GAME_READY and its inputs before they are sent anywhere.
 *
 * @returns {object}
 */
export function createSpectatorTransport() {
  const listeners = new Map();

  return {
    kind: "spectator",
    readyState: "closed",
    telemetryState: "spectator",
    bufferedAmount: 0,

    ...subscriptions(listeners),

    send() {
      return false;
    },

    /** @param {ArrayBuffer} data — one host→guest message, as sent. */
    deliver(data) {
      for (const listener of listeners.get("message") || []) listener({ data });
    },
  };
}

/**
 * The host's transport, with a copy of what it sends to its guest also handed
 * to `publish` — the stream spectators are drawn from.
 *
 * Snapshots are thinned to `minIntervalMs` apart (a spectator interpolates
 * between them, and the server relays every one); every other message — a
 * match starting, a match ending — is copied as it is sent.
 *
 * @param {object} transport
 * @param {(data: ArrayBuffer) => void} publish
 * @param {{stateType?: number, minIntervalMs?: number, now?: () => number}} [options]
 * @returns {object}
 */
export function createTeeTransport(transport, publish, options = {}) {
  const stateType = options.stateType ?? 0x80;
  const minIntervalMs = options.minIntervalMs ?? 66;
  const now = options.now ?? (() => performance.now());
  let lastStateAt = -Infinity;

  const copy = (data) => {
    if (!(data instanceof ArrayBuffer) || data.byteLength === 0) return;
    const type = new Uint8Array(data)[0];

    if (type === stateType) {
      const at = now();
      if (at - lastStateAt < minIntervalMs) return;
      lastStateAt = at;
    }

    publish(data);
  };

  return {
    kind: transport.kind,
    raw: transport.raw,

    get readyState() {
      return transport.readyState;
    },

    get telemetryState() {
      return transport.telemetryState;
    },

    get bufferedAmount() {
      return transport.bufferedAmount;
    },

    addEventListener(type, listener) {
      transport.addEventListener(type, listener);
    },

    removeEventListener(type, listener) {
      transport.removeEventListener(type, listener);
    },

    send(data) {
      const sent = transport.send(data);
      copy(data);
      return sent;
    },
  };
}

/**
 * Accept either the explicit transport contract or the legacy DataChannel.
 *
 * @param {object} transportOrChannel
 * @returns {object}
 */
export function normalizeGameTransport(transportOrChannel) {
  if (isGameTransport(transportOrChannel)) return transportOrChannel;
  return createDataChannelTransport(transportOrChannel);
}
