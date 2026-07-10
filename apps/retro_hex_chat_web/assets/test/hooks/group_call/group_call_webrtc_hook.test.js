import { afterEach, describe, expect, it, vi } from "vitest";

import GroupCallWebRTCHook from "../../../js/hooks/group_call/group_call_webrtc_hook.js";

function setupHook() {
  const hook = Object.create(GroupCallWebRTCHook);
  hook.el = { querySelector: vi.fn(() => null) };
  hook.pc = { addTrack: vi.fn() };
  hook.localStream = null;
  hook.mediaEnabled = { audio: true, video: true };
  hook.pushEvent = vi.fn();
  hook.channel = { push: vi.fn() };
  hook.pendingCandidates = [];
  hook.offerQueue = Promise.resolve();
  hook.lastAnsweredOfferSdp = null;

  return hook;
}

function setupNegotiationHook() {
  const hook = setupHook();
  const stream = {
    getTracks: vi.fn(() => []),
    getAudioTracks: vi.fn(() => []),
    getVideoTracks: vi.fn(() => []),
  };

  hook.localStream = stream;
  hook.pc = null;

  return hook;
}

class MockPeerConnection {
  constructor() {
    this.localDescription = null;
    this.remoteDescription = null;
    this.setRemoteDescription = vi.fn(async (description) => {
      this.remoteDescription = description;
      this.signalingState = "have-remote-offer";
    });
    this.createAnswer = vi.fn(async () => ({ type: "answer", sdp: "answer-sdp" }));
    this.setLocalDescription = vi.fn(async (description) => {
      this.localDescription = description;
      this.signalingState = "stable";
    });
    this.addEventListener = vi.fn();
    this.addTrack = vi.fn();
  }
}

describe("GroupCallWebRTCHook media fallback", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it("reports a recoverable warning when local media capture is denied", async () => {
    const hook = setupHook();
    vi.spyOn(console, "warn").mockImplementation(() => {});

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getUserMedia: vi.fn().mockRejectedValue(new Error("permission denied")),
      },
    });

    await hook._ensureLocalTracks();

    expect(hook.localStream).toBe(null);
    expect(hook.pc.addTrack).not.toHaveBeenCalled();
    expect(hook.pushEvent).toHaveBeenCalledWith("group_call_client_warning", {
      code: "media_capture_failed",
      message: "Could not access your microphone or camera. You joined receive-only.",
    });
    expect(hook.pushEvent).not.toHaveBeenCalledWith("group_call_client_error", expect.anything());
  });

  it("answers a repeated identical offer only once", async () => {
    const hook = setupNegotiationHook();
    const pc = new MockPeerConnection();
    vi.stubGlobal("RTCPeerConnection", function RTCPeerConnectionMock() {
      return pc;
    });

    await hook._handleOffer({ sdp: "offer-sdp", ice_servers: [] });
    await hook._handleOffer({ sdp: "offer-sdp", ice_servers: [] });

    expect(pc.setRemoteDescription).toHaveBeenCalledTimes(1);
    expect(pc.createAnswer).toHaveBeenCalledTimes(1);
    expect(hook.channel.push).toHaveBeenCalledTimes(1);
    expect(hook.channel.push).toHaveBeenCalledWith("group_call_answer", {
      sdp: "answer-sdp",
    });
  });

  it("serializes different offers on the same peer connection", async () => {
    const hook = setupNegotiationHook();
    const pc = new MockPeerConnection();
    vi.stubGlobal("RTCPeerConnection", function RTCPeerConnectionMock() {
      return pc;
    });

    await Promise.all([
      hook._handleOffer({ sdp: "offer-one", ice_servers: [] }),
      hook._handleOffer({ sdp: "offer-two", ice_servers: [] }),
    ]);

    expect(pc.setRemoteDescription).toHaveBeenNthCalledWith(1, {
      type: "offer",
      sdp: "offer-one",
    });
    expect(pc.setRemoteDescription).toHaveBeenNthCalledWith(2, {
      type: "offer",
      sdp: "offer-two",
    });
    expect(hook.channel.push).toHaveBeenCalledTimes(2);
  });
});
