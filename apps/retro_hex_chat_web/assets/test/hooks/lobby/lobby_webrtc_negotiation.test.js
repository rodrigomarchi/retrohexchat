/**
 * Negotiation-state coverage for the lobby WebRTC hook.
 *
 * These drive the hook against an RTCPeerConnection double that enforces the
 * signaling state machine and m-line ordering, so a description applied out of
 * turn raises the same DOMException Chrome raises instead of being absorbed.
 *
 * Every case here asserts the same invariant from a different angle: a stray,
 * stale or replayed description must be dropped, never handed to
 * setRemoteDescription. Handing it over throws, and the catch in
 * _handleRemoteDescription turns the throw into a full connection rebuild —
 * which re-sends the signals that caused it. That is the reconnect loop.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import LobbyWebRTCHook from "../../../js/hooks/lobby/lobby_webrtc_hook.js";
import { FakeRTCPeerConnection, sdpFor } from "../../helpers/rtc_peer_connection.js";
import { mountHook, simulateEvent, getPushEvents, cleanupDOM } from "../../helpers/hook_helper.js";

/** The hook only rebuilds the connection through _handleFailure, which retries. */
function recoveryAttempts(hook) {
  return getPushEvents(hook, "lobby_retry");
}

function signalsSent(hook) {
  return getPushEvents(hook, "lobby_signal");
}

async function flush() {
  await Promise.resolve();
  await Promise.resolve();
}

/** Bring an initiator up to a settled round: offer sent, answer applied. */
async function settledInitiator({ kinds = ["audio", "video"] } = {}) {
  const hook = mountHook(LobbyWebRTCHook);
  simulateEvent(hook, "lobby_start_offer", { ice_servers: [], turn_only: false });
  await flush();

  for (const kind of kinds) hook.pc.addTransceiver(kind, { direction: "sendrecv" });
  await hook._maybeOffer();
  await flush();

  const offer = signalsSent(hook).at(-1);
  await hook._handleSignal({
    type: "answer",
    sdp: sdpFor(kinds),
    epoch: offer.epoch,
    offer_id: offer.offer_id,
  });
  await flush();

  return { hook, offer, kinds };
}

/** Bring an answerer up to a settled round: offer applied, answer sent. */
async function settledAnswerer({ kinds = ["audio", "video"] } = {}) {
  const hook = mountHook(LobbyWebRTCHook);
  simulateEvent(hook, "lobby_start_answer", { ice_servers: [], turn_only: false });
  await flush();

  await hook._handleSignal({
    type: "offer",
    sdp: sdpFor(kinds),
    epoch: 1,
    offer_id: "p2p-1-1",
  });
  await flush();

  return { hook, kinds };
}

describe("LobbyWebRTCHook negotiation state", () => {
  let originalRTC;

  beforeEach(() => {
    originalRTC = globalThis.RTCPeerConnection;
    globalThis.RTCPeerConnection = FakeRTCPeerConnection;
  });

  afterEach(() => {
    vi.useRealTimers();
    globalThis.RTCPeerConnection = originalRTC;
    cleanupDOM();
    vi.restoreAllMocks();
  });

  it("settles a clean round without recovering", async () => {
    const { hook } = await settledInitiator();

    expect(hook.pc.signalingState).toBe("stable");
    expect(recoveryAttempts(hook)).toHaveLength(0);
  });

  it("drops an answer for a round that already settled", async () => {
    const { hook, kinds } = await settledInitiator();

    // A second answer carrying a fresh offer_id slips past the identity dedup,
    // and the connection is back in `stable` with no local offer to answer.
    await hook._handleSignal({
      type: "answer",
      sdp: sdpFor(kinds),
      epoch: hook.signalingEpoch,
      offer_id: "p2p-1-99",
    });
    await flush();

    expect(hook.pc.signalingState).toBe("stable");
    expect(recoveryAttempts(hook)).toHaveLength(0);
  });

  it("drops an answer aimed at the peer that owns the offer", async () => {
    const { hook } = await settledAnswerer();

    // The answerer has applied a remote offer and never offers itself, so an
    // inbound answer can only be misrouted or replayed back at it.
    await hook._handleSignal({
      type: "answer",
      sdp: sdpFor(["audio", "video"]),
      epoch: hook.signalingEpoch,
      offer_id: "p2p-1-1",
    });
    await flush();

    expect(recoveryAttempts(hook)).toHaveLength(0);
  });

  it("ignores an inbound offer while it owns the offer role", async () => {
    const hook = mountHook(LobbyWebRTCHook);
    simulateEvent(hook, "lobby_start_offer", { ice_servers: [], turn_only: false });
    await flush();

    hook.pc.addTransceiver("audio", { direction: "sendrecv" });
    await hook._maybeOffer();
    await flush();

    // Single-offerer: an offer reaching the initiator is its own, echoed back.
    // Applying it moves the connection to have-remote-offer, and the real
    // answer for the outstanding offer is then unapplicable.
    await hook._handleSignal({
      type: "offer",
      sdp: sdpFor(["audio"]),
      epoch: hook.signalingEpoch,
      offer_id: "p2p-1-1",
    });
    await flush();

    expect(hook.pc.signalingState).toBe("have-local-offer");
    expect(recoveryAttempts(hook)).toHaveLength(0);
  });

  it("does not desync when a settled description is replayed", async () => {
    const { hook, offer, kinds } = await settledInitiator();

    // Replay hands back whatever the peer last sent, without regard for the
    // state this side has since reached.
    simulateEvent(hook, "lobby_signal_replay", {
      events: [
        {
          event: "lobby_signal",
          payload: {
            type: "answer",
            sdp: sdpFor(kinds),
            epoch: offer.epoch,
            offer_id: offer.offer_id,
            replay: true,
          },
        },
      ],
    });
    await flush();

    expect(hook.pc.signalingState).toBe("stable");
    expect(recoveryAttempts(hook)).toHaveLength(0);
  });

  it("renegotiates between two peers without desyncing", async () => {
    const initiator = mountHook(LobbyWebRTCHook);
    const answerer = mountHook(LobbyWebRTCHook);

    simulateEvent(initiator, "lobby_start_offer", { ice_servers: [], turn_only: false });
    simulateEvent(answerer, "lobby_start_answer", { ice_servers: [], turn_only: false });
    await flush();

    // Stands in for the LiveView relay, which drops a peer's own signals.
    const delivered = { initiator: 0, answerer: 0 };
    const pump = async () => {
      for (const [from, to, key] of [
        [initiator, answerer, "initiator"],
        [answerer, initiator, "answerer"],
      ]) {
        const pending = signalsSent(from).slice(delivered[key]);
        delivered[key] = signalsSent(from).length;
        for (const payload of pending) {
          await to._handleSignal(payload);
          await flush();
        }
      }
    };

    initiator.pc.addTrack({ kind: "audio" });
    await initiator._maybeOffer(["audio"]);
    await flush();
    await pump();
    await pump();

    expect(initiator.pc.signalingState).toBe("stable");
    expect(answerer.pc.signalingState).toBe("stable");

    // The answerer turns its camera on and asks for a re-offer carrying video.
    answerer.pc.addTrack({ kind: "video" });
    answerer._requestRenegotiation(false, { reason: "video_on" });
    const request = getPushEvents(answerer, "lobby_renegotiate").at(-1);
    await initiator._handleRenegotiate(request);
    await flush();
    await pump();
    await pump();

    expect(initiator.pc.signalingState).toBe("stable");
    expect(answerer.pc.signalingState).toBe("stable");
    expect(initiator.pc.negotiatedMLines).toEqual(answerer.pc.negotiatedMLines);
    expect(recoveryAttempts(initiator)).toHaveLength(0);
    expect(recoveryAttempts(answerer)).toHaveLength(0);
  });

  it("rebuilds the connection for a connection_reset offer at the same epoch", async () => {
    const { hook } = await settledAnswerer({ kinds: ["audio", "video"] });
    const staleConnection = hook.pc;

    // The initiator rebuilt its connection and re-offered from scratch, so its
    // m-line layout no longer extends the one this side settled on. Only a
    // matching rebuild here can accept it; the epoch does not have to advance
    // for the peer's connection to be brand new.
    await hook._handleSignal({
      type: "offer",
      sdp: sdpFor(["audio"]),
      epoch: hook.signalingEpoch,
      offer_id: "p2p-1-2",
      connection_reset: true,
    });
    await flush();

    expect(hook.pc).not.toBe(staleConnection);
    expect(recoveryAttempts(hook)).toHaveLength(0);
  });
});
