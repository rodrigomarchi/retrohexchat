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

    addEventListener(type, listener) {
      if (!listeners.has(type)) listeners.set(type, new Set());
      listeners.get(type).add(listener);
    },

    removeEventListener(type, listener) {
      listeners.get(type)?.delete(listener);
    },

    send() {
      return true;
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
