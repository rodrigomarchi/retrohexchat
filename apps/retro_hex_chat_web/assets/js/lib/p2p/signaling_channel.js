/**
 * The P2P signaling wire, as a Phoenix Channel.
 *
 * Offers, answers, candidates, the answerer's renegotiation request and the
 * replay that fills a reconnect's gap used to ride the LiveView socket. They
 * ride `p2p:<session_token>` now, which is a socket of its own: the negotiation
 * survives the page it started on, and the same wire can be shared by more than
 * one host.
 *
 * Everything else the connection controller says — it failed, it is retrying,
 * here are its stats — still goes to the LiveView, because those drive chat
 * chrome rather than the peer. The router lives in the hook; this module only
 * knows how to open the wire and how to close it.
 *
 * Phoenix rejoins a channel on its own after a socket drop. What does not come
 * back on its own is the negotiation state, so the join reply carries the
 * replay: joining is itself the statement "I am listening and I may have missed
 * something".
 */
import { Socket } from "phoenix";
import { log } from "../logger.js";

// Everything the peer needs to hear. Anything not named here is chat chrome and
// belongs to the LiveView — a wildcard would send the whole controller's
// vocabulary over a wire nobody on the other end is listening to.
export const SIGNAL_EVENTS = Object.freeze([
  "lobby_signal",
  "lobby_renegotiate",
  "lobby_signal_replay_request",
]);

export function createSignalingChannel({ sessionToken, joinToken, onError }) {
  const handlers = new Map();
  let socket = null;
  let channel = null;

  const emit = (event, payload) => {
    const handler = handlers.get(event);
    if (handler) handler(payload || {});
  };

  return {
    connect() {
      if (!sessionToken || !joinToken) {
        log.warn("p2p: signaling channel not connected — no session on the anchor");
        return;
      }

      socket = new Socket("/socket");
      socket.connect();

      channel = socket.channel(`p2p:${sessionToken}`, { join_token: joinToken });

      channel.on("lobby_signal", (payload) => emit("lobby_signal", payload));
      channel.on("lobby_renegotiate", (payload) => emit("lobby_renegotiate", payload));
      channel.on("lobby_signal_replay", (payload) => emit("lobby_signal_replay", payload));
      channel.on("lobby_signal_rejected", (payload) => emit("lobby_signal_rejected", payload));

      channel
        .join()
        .receive("ok", (reply) => {
          // The catch-up rides the join reply, so a rejoin after a dropped
          // socket lands the missed signals without a round trip of its own.
          if (reply?.replay) emit("lobby_signal_replay", reply.replay);
        })
        .receive("error", (reply) => {
          log.warn(`p2p: signaling channel refused (${reply?.reason || "unknown"})`);
          if (onError) onError(reply || {});
        })
        .receive("timeout", () => {
          log.warn("p2p: signaling channel join timed out");
        });
    },

    /** Register what to do with an event the peer sent. */
    on(event, handler) {
      handlers.set(event, handler);
      return this;
    },

    /**
     * Send one signaling event. Before the wire is open there is nowhere for it
     * to go, and it is dropped — loudly, because a swallowed signal looks
     * exactly like a peer that never answered.
     */
    send(event, payload) {
      if (!channel) {
        log.warn(`p2p: dropped ${event} — the signaling channel is not open`);
        return;
      }

      channel.push(event, payload || {});
    },

    disconnect() {
      try {
        channel?.leave();
      } catch (error) {
        log.warn(`p2p: leaving the signaling channel failed (${error?.message || error})`);
      }

      try {
        socket?.disconnect();
      } catch (error) {
        log.warn(`p2p: disconnecting the signaling socket failed (${error?.message || error})`);
      }

      channel = null;
      socket = null;
      handlers.clear();
    },
  };
}
