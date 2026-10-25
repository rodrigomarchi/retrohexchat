/**
 * Every data channel a P2P session opens over its one peer connection.
 *
 * The connection (`lobby_connection.js`) creates each channel on the offering
 * side, adopts it by label on the answering side, announces it on the
 * `#lobby-webrtc` element when it opens and closes, and drops it on teardown —
 * all from this table. A feature that needs a channel of its own adds an entry
 * here and subscribes with `subscribeDataChannel`; it never touches the peer
 * connection.
 *
 * File transfer and games want opposite things from the same SCTP
 * association, so they are configured as opposites. A file must arrive intact
 * and in order, and it is happy to wait. Game state must arrive *now*: a
 * snapshot is superseded by the next one 16 ms later, so retransmitting a lost
 * one delivers stale truth, and delivering it in order holds every fresher
 * snapshot behind it. That head-of-line blocking is what turns a single dropped
 * datagram into a freeze-then-jump on the guest, which is why the game channel
 * is unreliable and unordered. Priority is the other half: without it a 64 KB
 * file chunk transmits ahead of a 25-byte snapshot simply for being queued
 * first.
 *
 * @module p2p/data_channels
 */

/**
 * @typedef {object} DataChannelSpec
 * @property {string} label       the channel's label, the same on both peers
 * @property {RTCDataChannelInit} options
 * @property {string} property    where the connection keeps it (`conn.fileChannel`)
 * @property {string} elementKey  where the open channel is left on the element,
 *                                for a subscriber that mounts after it opened
 * @property {string} readyEvent  CustomEvent dispatched when it opens
 * @property {string} closedEvent CustomEvent dispatched when it closes
 * @property {string} statsKey    its key in the per-feature stats payload
 */

/** @type {ReadonlyArray<DataChannelSpec>} */
export const DATA_CHANNELS = Object.freeze([
  Object.freeze({
    label: "filetransfer",
    options: Object.freeze({ ordered: true, priority: "low" }),
    property: "fileChannel",
    elementKey: "_fileTransferChannel",
    readyEvent: "ft_channel_ready",
    closedEvent: "ft_channel_closed",
    statsKey: "file",
  }),
  Object.freeze({
    label: "gamedata",
    options: Object.freeze({ ordered: false, maxRetransmits: 0, priority: "high" }),
    property: "gameChannel",
    elementKey: "_gameDataChannel",
    readyEvent: "game_channel_ready",
    closedEvent: "game_channel_closed",
    statsKey: "game",
  }),
]);

/**
 * The spec for a label, or undefined for one this side does not know.
 * @param {string} label
 * @returns {DataChannelSpec | undefined}
 */
export function dataChannelSpec(label) {
  return DATA_CHANNELS.find((spec) => spec.label === label);
}

/**
 * Follow one channel on the connection's element: `onOpen(channel)` when it
 * opens — at once if it already did before this subscriber mounted — and
 * `onClose()` when it closes. Returns the function that stops following.
 *
 * @param {HTMLElement | null} webrtcEl the `#lobby-webrtc` element
 * @param {string} label
 * @param {{ onOpen: (channel: RTCDataChannel) => void, onClose?: () => void }} handlers
 * @returns {() => void}
 */
export function subscribeDataChannel(webrtcEl, label, { onOpen, onClose }) {
  const spec = dataChannelSpec(label);
  if (!spec) throw new Error(`unknown data channel "${label}"`);
  if (!webrtcEl) return () => {};

  const opened = (event) => onOpen(event.detail.channel);
  const closed = () => onClose?.();
  webrtcEl.addEventListener(spec.readyEvent, opened);
  webrtcEl.addEventListener(spec.closedEvent, closed);

  const current = webrtcEl[spec.elementKey];
  if (current && current.readyState === "open") onOpen(current);

  return () => {
    webrtcEl.removeEventListener(spec.readyEvent, opened);
    webrtcEl.removeEventListener(spec.closedEvent, closed);
  };
}
