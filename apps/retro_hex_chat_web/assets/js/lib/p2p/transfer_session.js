/**
 * The file-transfer protocol as a pure reducer over discrete events.
 *
 * The hook used to hold the sequencing the moduledoc said it must not: what a
 * peer-accept means depending on role, what a hash result decides, how a cancel
 * or a resume advances the session. Those transitions live here now as
 * `step(session, event) -> {session, effects}`, tested without a DataChannel.
 *
 * What stays in the hook is genuine I/O: the async chunk-sending loop with its
 * bufferedAmount backpressure, hashing, file assembly and the download. Those
 * are effects the hook executes; the reducer only decides.
 *
 * `session` is the mutable struct from lib/p2p/file_transfer.js. The reducer
 * advances it in place and returns it (or null once cleaned up) — the value
 * under test is the resulting state and the effect list, not struct immutability.
 *
 * @module p2p/transfer_session
 */
import { MSG, STATE, cleanupSession, markChunksReceived } from "./file_transfer.js";
import { t } from "../i18n.js";

/** Effect kinds the hook executes. */
export const EFFECT = {
  SEND_CONTROL: "send_control", // { code, payload, requireOpen }
  PUSH: "push", // { event, payload }
  START_PROGRESS: "start_progress",
  STOP_PROGRESS: "stop_progress",
  START_SENDING: "start_sending",
  PROCESS_QUEUE: "process_queue",
  DOWNLOAD: "download", // { blob, fileName }
};

const send = (code, payload, requireOpen = false) => ({
  type: EFFECT.SEND_CONTROL,
  code,
  payload,
  requireOpen,
});
const push = (event, payload = {}) => ({ type: EFFECT.PUSH, event, payload });
const effect = (type, extra = {}) => ({ type, ...extra });

/**
 * Advance the session for one protocol event.
 *
 * @param {object|null} session
 * @param {{type: string, [key: string]: unknown}} event
 * @param {{now?: () => number}} [deps] injectable clock for start times
 * @returns {{session: object|null, effects: object[]}}
 */
export function step(session, event, deps = {}) {
  const now = deps.now || (() => Date.now());

  switch (event.type) {
    case "peer_accept":
      return peerAccept(session, now);
    case "peer_reject":
      return peerReject(session);
    case "sender_hash_result":
      return senderHashResult(session, event.match);
    case "receiver_hash_result":
      return receiverHashResult(session, event.match, event.blob);
    case "local_cancel":
      return localCancel(session, event.nickname);
    case "incoming_cancel":
      return incomingCancel(session, event.cancelledBy);
    case "channel_close":
      return channelClose(session);
    case "incoming_have_chunks":
      return incomingHaveChunks(session, event.indices);
    case "retry_request":
      return retryRequest(session, now);
    case "incoming_retry":
      return incomingRetry(session, now);
    default:
      return { session, effects: [] };
  }
}

function peerAccept(session, now) {
  if (!session) return { session, effects: [] };

  if (session.role === "sender") {
    session.state = STATE.TRANSFERRING;
    session.startTime = now();
    return {
      session,
      effects: [effect(EFFECT.START_PROGRESS), push("ft_accepted"), effect(EFFECT.START_SENDING)],
    };
  }

  // Receiver acknowledges an accept it initiated.
  session.startTime = now();
  return {
    session,
    effects: [
      send(MSG.FILE_ACCEPT, { transferId: session.transferId }),
      effect(EFFECT.START_PROGRESS),
      push("ft_accepted"),
    ],
  };
}

function peerReject(session) {
  if (!session) return { session, effects: [] };

  if (session.role === "sender") {
    session.state = STATE.REJECTED;
    cleanupSession(session);
    return { session: null, effects: [push("ft_rejected"), effect(EFFECT.PROCESS_QUEUE)] };
  }

  // Receiver declines: tell the sender, then clean up.
  cleanupSession(session);
  return {
    session: null,
    effects: [
      send(MSG.FILE_REJECT, { transferId: session.transferId }),
      push("ft_rejected"),
      effect(EFFECT.PROCESS_QUEUE),
    ],
  };
}

function senderHashResult(session, match) {
  if (!session || session.role !== "sender") return { session, effects: [] };

  if (match) {
    session.state = STATE.COMPLETED;
    const fileName = session.fileName;
    cleanupSession(session);
    return {
      session: null,
      effects: [
        effect(EFFECT.STOP_PROGRESS),
        push("ft_completed", { file_name: fileName }),
        effect(EFFECT.PROCESS_QUEUE),
      ],
    };
  }

  session.state = STATE.FAILED;
  return {
    session,
    effects: [
      effect(EFFECT.STOP_PROGRESS),
      push("ft_failed", { reason: t("Integrity check failed") }),
    ],
  };
}

function receiverHashResult(session, match, blob) {
  if (!session) return { session, effects: [] };

  if (match && blob) {
    session.state = STATE.COMPLETED;
    const fileName = session.fileName;
    cleanupSession(session);
    return {
      session: null,
      effects: [
        effect(EFFECT.DOWNLOAD, { blob, fileName }),
        push("ft_completed", { file_name: fileName }),
        effect(EFFECT.PROCESS_QUEUE),
      ],
    };
  }

  session.state = STATE.FAILED;
  return { session, effects: [push("ft_failed", { reason: t("Integrity check failed") })] };
}

function localCancel(session, nickname) {
  if (!session) return { session, effects: [] };

  const transferId = session.transferId;
  session.state = STATE.CANCELLED;
  cleanupSession(session);
  return {
    session: null,
    effects: [
      send(MSG.CANCEL, { transferId, cancelledBy: nickname }, true),
      effect(EFFECT.STOP_PROGRESS),
      push("ft_cancelled", { cancelled_by: nickname }),
      effect(EFFECT.PROCESS_QUEUE),
    ],
  };
}

function incomingCancel(session, cancelledBy) {
  if (!session) return { session, effects: [] };

  session.state = STATE.CANCELLED;
  cleanupSession(session);
  return {
    session: null,
    effects: [
      effect(EFFECT.STOP_PROGRESS),
      push("ft_cancelled", { cancelled_by: cancelledBy }),
      effect(EFFECT.PROCESS_QUEUE),
    ],
  };
}

function channelClose(session) {
  if (session && (session.state === STATE.TRANSFERRING || session.state === STATE.OFFERING)) {
    session.state = STATE.PAUSED;
    return { session, effects: [effect(EFFECT.STOP_PROGRESS), push("ft_paused")] };
  }

  return { session, effects: [] };
}

function incomingHaveChunks(session, indices) {
  if (!session || session.role !== "sender") return { session, effects: [] };

  markChunksReceived(session, indices);
  session.state = STATE.TRANSFERRING;
  session.nextChunkIndex = 0;
  return {
    session,
    effects: [effect(EFFECT.START_PROGRESS), push("ft_resumed"), effect(EFFECT.START_SENDING)],
  };
}

function retryRequest(session, now) {
  if (!session || session.role !== "sender") return { session, effects: [] };

  session.sentSet = new Set();
  session.nextChunkIndex = 0;
  session.bytesSent = 0;
  session.speedSamples = [];
  session.state = STATE.TRANSFERRING;
  session.startTime = now();
  return {
    session,
    effects: [
      send(MSG.RETRY, { transferId: session.transferId }, true),
      effect(EFFECT.START_PROGRESS),
      effect(EFFECT.START_SENDING),
    ],
  };
}

function incomingRetry(session, now) {
  if (!session || session.role !== "receiver") return { session, effects: [] };

  session.chunks = new Array(session.totalChunks).fill(null);
  session.receivedSet = new Set();
  session.bytesReceived = 0;
  session.speedSamples = [];
  session.state = STATE.TRANSFERRING;
  session.startTime = now();
  return {
    session,
    effects: [
      effect(EFFECT.START_PROGRESS),
      push("ft_progress", { percent: 0, speed: "0 B/s", eta: "--" }),
    ],
  };
}
