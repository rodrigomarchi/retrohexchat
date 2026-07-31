/**
 * Negotiation-state coverage for the group call hook.
 *
 * The browser is answer-only here: the SFU owns every offer. These drive the
 * hook against an RTCPeerConnection double that enforces the signaling state
 * machine and m-line ordering, so an offer applied to a connection that can no
 * longer accept it raises the same DOMException Chrome raises.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import GroupCallWebRTCHook from "../../../js/hooks/group_call/group_call_webrtc_hook.js";
import { FakeRTCPeerConnection, sdpFor, mLinesOf } from "../../helpers/rtc_peer_connection.js";

function buildHook({ localKinds = ["audio"] } = {}) {
  const hook = Object.create(GroupCallWebRTCHook);

  hook.el = { querySelector: vi.fn(() => null) };
  hook.pc = null;
  hook.localStream = null;
  hook.mediaEnabled = { audio: true, video: false };
  hook.pushEvent = vi.fn();
  hook.channel = { push: vi.fn() };
  hook.pendingCandidates = [];
  hook.remoteCandidateFailures = 0;
  hook.offerQueue = Promise.resolve();
  hook.lastAnsweredOfferSdp = null;
  hook.lastAnsweredOfferId = null;
  hook.offerWatchdogTimer = null;
  hook.offerWatchdogAttempts = 0;
  hook.rejoinEpoch = 0;
  hook.rejoining = false;
  hook.closing = false;
  hook.recoveryAttempts = 0;
  hook.maxRecoveryAttempts = 3;
  hook.localSenders = [];
  hook._sendersPc = null;

  // Publishing local media is what puts this side's own m-lines on the wire;
  // model it as the track adds it performs, not as the device plumbing.
  hook._ensureLocalTracks = vi.fn(async () => {
    for (const kind of localKinds) hook.pc.addTrack({ kind });
  });
  hook._flushPendingCandidates = vi.fn(async () => {});
  hook._notifyError = vi.fn();
  hook._notifyWarning = vi.fn();
  hook._rejoinConnection = vi.fn();
  hook._clearOfferWatchdog = vi.fn();
  hook._scheduleOfferWatchdog = vi.fn();

  return hook;
}

function answerSent(hook) {
  const calls = hook.channel.push.mock.calls.filter(([event]) => event === "group_call_answer");
  return calls.at(-1)?.[1] || null;
}

describe("GroupCallWebRTCHook negotiation state", () => {
  let originalRTC;

  beforeEach(() => {
    originalRTC = globalThis.RTCPeerConnection;
    globalThis.RTCPeerConnection = FakeRTCPeerConnection;
  });

  afterEach(() => {
    globalThis.RTCPeerConnection = originalRTC;
    vi.restoreAllMocks();
  });

  it("answers an offer with the m-line layout the offer asked for", async () => {
    const hook = buildHook();

    await hook._handleOffer({
      sdp: sdpFor(["audio", "video"]),
      ice_servers: [],
      offer_id: "gc-1-1",
    });

    expect(hook.pc.signalingState).toBe("stable");
    expect(mLinesOf(answerSent(hook).sdp)).toEqual(["audio", "video"]);
    expect(hook._notifyError).not.toHaveBeenCalled();
  });

  it("settles a follow-up offer that appends a participant's m-lines", async () => {
    const hook = buildHook();

    await hook._handleOffer({
      sdp: sdpFor(["audio", "video"]),
      ice_servers: [],
      offer_id: "gc-1-1",
    });
    await hook._handleOffer({
      sdp: sdpFor(["audio", "video", "audio", "video"]),
      ice_servers: [],
      offer_id: "gc-1-2",
    });

    expect(hook.pc.signalingState).toBe("stable");
    expect(mLinesOf(answerSent(hook).sdp)).toEqual(["audio", "video", "audio", "video"]);
    expect(hook._notifyError).not.toHaveBeenCalled();
  });

  it("rejoins when the SFU re-offers from a rebuilt connection", async () => {
    const hook = buildHook();

    await hook._handleOffer({
      sdp: sdpFor(["audio", "video"]),
      ice_servers: [],
      offer_id: "gc-1-1",
    });
    const staleConnection = hook.pc;

    // The SFU rebuilt its peer and re-offers from scratch, so the layout no
    // longer extends the one this connection settled on. The old connection can
    // never accept it; only a rejoin can.
    await hook._handleOffer({ sdp: sdpFor(["audio"]), ice_servers: [], offer_id: "gc-2-1" });

    expect(hook._rejoinConnection).toHaveBeenCalled();
    expect(hook.pc).toBe(staleConnection);
  });
});
