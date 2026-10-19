/**
 * The wire a watched P2P match travels on, `spectate:<session_token>`.
 *
 * The two players' DataChannel never reaches the server, so watching needs a
 * second path: the host sends a thinned copy of what it sends its guest here,
 * and the server hands it to everybody watching. One module for both ends —
 * the host publishes with the session's join token, a watcher only listens —
 * because they are the same channel seen from either side.
 *
 * The server decides who may do what (`SpectateChannel`): a session nobody
 * offered in the open refuses both, and a host who is no longer hosting is
 * refused as a publisher. A refusal is said once and closes the wire — left
 * open, Phoenix would ask again every few seconds for the whole match — and
 * changes nothing else: the match is played the same whether anybody can
 * watch it or not.
 */
import { Socket } from "phoenix";
import { log } from "../logger.js";
import { createDataChannelTransport, createTeeTransport } from "./transport.js";

/**
 * @param {object} options
 * @param {string|null} options.token — the session token
 * @param {string|null} [options.joinToken] — the P2P join token; a host's only
 * @param {(data: ArrayBuffer) => void} [options.onFrame] — a watcher's frames
 * @param {(reply: object) => void} [options.onRefused]
 * @param {{createSocket?: () => object}} [deps]
 * @returns {{connect: () => void, publish: (data: ArrayBuffer) => void, destroy: () => void}}
 */
export function createSpectateWire(
  { token, joinToken = null, onFrame = () => {}, onRefused = () => {} },
  { createSocket = () => new Socket("/socket") } = {},
) {
  let socket = null;
  let channel = null;
  let joined = false;

  const wire = {
    connect() {
      if (socket || !token) return;

      socket = createSocket();
      socket.connect();
      channel = socket.channel(`spectate:${token}`, joinToken ? { join_token: joinToken } : {});

      channel.on("frame", (data) => {
        if (data instanceof ArrayBuffer) onFrame(data);
      });

      channel
        .join()
        .receive("ok", () => {
          joined = true;
        })
        .receive("error", (reply) => {
          log.warn(`spectate: not relayed (${reply?.reason || "unknown"})`);
          wire.destroy();
          onRefused(reply || {});
        })
        .receive("timeout", () => log.warn("spectate: join timed out"));
    },

    publish(data) {
      if (joined) channel.push("frame", data);
    },

    destroy() {
      joined = false;

      try {
        channel?.leave();
        socket?.disconnect();
      } catch (error) {
        log.warn(`spectate: closing the wire failed (${error?.message || error})`);
      }

      channel = null;
      socket = null;
    },
  };

  return wire;
}

/**
 * The host's transport for a match: its DataChannel, with a copy of what it
 * sends its guest published for whoever watches. The session's tokens come
 * from the P2P anchor, which already carries them for signaling.
 *
 * @param {RTCDataChannel} dataChannel
 * @param {HTMLElement|null} anchor — `#lobby-webrtc`
 * @param {{createSocket?: () => object}} [deps]
 * @returns {{transport: object, destroy: () => void}}
 */
export function createHostTransport(dataChannel, anchor, deps = {}) {
  const wire = createSpectateWire(
    { token: anchor?.dataset.sessionToken || null, joinToken: anchor?.dataset.joinToken || null },
    deps,
  );

  wire.connect();

  return {
    transport: createTeeTransport(createDataChannelTransport(dataChannel), (data) =>
      wire.publish(data),
    ),
    destroy: () => wire.destroy(),
  };
}
