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
  hook.layoutState = {
    mode: "auto",
    focusedParticipantId: null,
    focusedStreamId: null,
    selfView: "tile",
    sidebarOpen: true,
  };
  hook.participantsById = new Map();
  hook.tracksById = new Map();
  hook.tracksByStreamId = new Map();
  hook.tracksByWebrtcTrackId = new Map();
  hook.remoteTiles = new Map();

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

function setupLayoutHook() {
  const hook = setupHook();
  const el = document.createElement("div");
  el.dataset.layoutMode = "auto";
  el.dataset.selfView = "tile";
  el.dataset.sidebarOpen = "true";
  el.innerHTML = `
    <div data-group-call-video-grid>
      <div data-group-call-remote-placeholder></div>
      <div
        data-group-call-video-tile
        data-group-call-local-tile
        data-local="true"
        data-media-audio="true"
        data-media-video="true"
      >
        <video data-group-call-local-video></video>
      </div>
    </div>
  `;

  hook.el = el;
  hook.layoutState = hook._layoutStateFromDataset();
  hook._bindLocalTile();
  document.body.appendChild(el);

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
    document.body.innerHTML = "";
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

  it("keeps the same remote video element and stream while focusing a participant", () => {
    const hook = setupLayoutHook();
    const stream = { id: "stream-456" };

    hook._syncLayoutState({
      participants: [
        {
          id: 456,
          nickname: "Ada",
          status: "connected",
          media_state: { audio: true, video: true },
        },
      ],
      tracks: [
        {
          id: 1,
          participant_id: 456,
          kind: "video",
          status: "active",
          stream_id: "stream-456",
          webrtc_track_id: "track-456",
        },
      ],
    });

    hook._attachRemoteStream(stream, { id: "track-456" });

    const tile = hook.el.querySelector('[data-stream-id="stream-456"]');
    const video = tile.querySelector("video");
    expect(video.srcObject).toBe(stream);
    expect(tile.dataset.participantId).toBe("456");

    hook._syncLayoutState({
      mode: "focus",
      focused_participant_id: 456,
      self_view: "tile",
      sidebar_open: true,
    });

    const videoAfterFocus = hook.el.querySelector('[data-stream-id="stream-456"] video');
    expect(videoAfterFocus).toBe(video);
    expect(videoAfterFocus.srcObject).toBe(stream);
    expect(tile.dataset.focused).toBe("true");
  });

  it("emits focus and clear-focus events from video tiles", () => {
    const hook = setupLayoutHook();
    const stream = { id: "stream-789" };

    hook._syncLayoutState({
      participants: [{ id: 789, nickname: "Grace", media_state: { audio: true, video: true } }],
      tracks: [{ id: 2, participant_id: 789, stream_id: "stream-789" }],
    });
    hook._attachRemoteStream(stream);

    const tile = hook.el.querySelector('[data-stream-id="stream-789"]');
    tile.click();

    expect(hook.pushEvent).toHaveBeenCalledWith("group_call_focus_participant", {
      participant_id: "789",
      "participant-id": "789",
    });

    hook._syncLayoutState({ mode: "focus", focused_participant_id: 789 });
    tile.click();

    expect(hook.pushEvent).toHaveBeenCalledWith("group_call_clear_focus", {});
  });

  it("removes the local tile from layout counts when self view is hidden", () => {
    const hook = setupLayoutHook();
    const host = hook.el.querySelector("[data-group-call-video-grid]");

    expect(host.dataset.tileCount).toBe("1");

    hook._syncLayoutState({ self_view: "hidden" });

    expect(hook.el.dataset.selfView).toBe("hidden");
    expect(host.dataset.tileCount).toBe("0");
  });
});
