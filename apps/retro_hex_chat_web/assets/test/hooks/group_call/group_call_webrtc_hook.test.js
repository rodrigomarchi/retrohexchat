import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import GroupCallWebRTCHook from "../../../js/hooks/group_call/group_call_webrtc_hook.js";
import { FakeRTCPeerConnection } from "../../helpers/rtc_peer_connection.js";
import { createTrackRegistry } from "../../../js/lib/group_call/track_registry.js";
import { createParticipantRegistry } from "../../../js/lib/group_call/participant_registry.js";
import { createTileView } from "../../../js/lib/group_call/tile_view.js";

let hooks = [];

function setupHook() {
  const hook = Object.create(GroupCallWebRTCHook);
  hook.el = { querySelector: vi.fn(() => null) };
  hook.pc = { addTrack: vi.fn() };
  hook.localStream = null;
  hook.mediaEnabled = { audio: true, video: true };
  hook.serverAudioMuted = false;
  hook.serverVideoBlocked = false;
  hook.devicePreferences = {
    audioInputId: null,
    videoInputId: null,
    audioOutputId: null,
  };
  hook.pushEvent = vi.fn();
  hook.channel = { push: vi.fn() };
  hook.pendingCandidates = [];
  hook.remoteCandidateFailures = 0;
  hook.offerQueue = Promise.resolve();
  hook.lastAnsweredOfferSdp = null;
  hook.lastAnsweredOfferId = null;
  hook.layoutState = {
    mode: "auto",
    focusedParticipantId: null,
    focusedStreamId: null,
    selfView: "tile",
    sidebarOpen: true,
    pinnedParticipantIds: [],
  };
  hook.participantRegistry = createParticipantRegistry();
  hook.trackRegistry = createTrackRegistry();
  hook.tileView = createTileView(hook.el, { onToggleFocus: (tile) => hook._toggleTileFocus(tile) });
  hook.remoteVideoStalls = new Map();
  hook.statsTimer = null;
  hook.statsPrev = null;
  hook.localSenders = [];
  hook._sendersPc = null;
  hook.participantStatsPrev = null;
  hook.participantQualityById = new Map();
  hook.activeSpeakerParticipantId = null;
  hook.reactionTimers = new Map();
  hook.pushToTalkActive = false;
  hook.pushToTalkRestoreAudio = null;
  hook.screenShare = { active: false, stream: null, track: null };
  hook.screenShareBlocked = false;
  hook.recoveryTimer = null;
  hook.recoveryAttempts = 0;
  hook.recoveryActivityDeferrals = 0;
  hook.maxRecoveryAttempts = 3;
  hook.offerWatchdogTimer = null;
  hook.offerWatchdogAttempts = 0;
  hook.rejoinEpoch = 0;
  hook.rejoining = false;

  hooks.push(hook);
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
  el.dataset.pinnedParticipantIds = "";
  el.innerHTML = `
    <div data-group-call-video-grid>
      <div data-group-call-remote-placeholder></div>
      <template data-group-call-remote-tile-template>
        <div
          class="group-call-video-tile group-call-video-tile--remote"
          data-group-call-video-tile
          data-local="false"
          role="button"
          tabindex="0"
        >
          <div class="group-call-video-tile__nameplate">
            <span data-group-call-tile-name>Remote</span>
            <span class="group-call-video-tile__badges">
              <span data-group-call-audio-badge>
                <svg data-test-icon="remote-microphone"></svg>
              </span>
              <span data-group-call-video-badge>
                <svg data-test-icon="remote-camera"></svg>
              </span>
              <span data-group-call-quality-badge data-quality-level="unknown" hidden>
                <svg data-quality-icon="high"></svg>
                <svg data-quality-icon="low"></svg>
              </span>
            </span>
          </div>
        </div>
      </template>
      <template data-group-call-reaction-icon-template="clap">
        <span data-test-icon="reaction-clap"><svg></svg></span>
      </template>
      <div
        data-group-call-video-tile
        data-group-call-local-tile
        data-local="true"
        data-media-audio="true"
        data-media-video="true"
      >
        <video data-group-call-local-video></video>
        <div data-group-call-local-empty>
          <span data-group-call-local-empty-title></span>
          <span data-group-call-local-empty-detail></span>
        </div>
      </div>
    </div>
  `;

  hook.el = el;
  hook.tileView = createTileView(el, { onToggleFocus: (tile) => hook._toggleTileFocus(tile) });
  hook.layoutState = hook._layoutStateFromDataset();
  hook._bindLocalTile();
  document.body.appendChild(el);

  return hook;
}

// Spied over the faithful double so call counts stay assertable while the
// signaling state machine and m-line rules still apply.
class MockPeerConnection extends FakeRTCPeerConnection {
  constructor() {
    super();

    for (const method of [
      "setRemoteDescription",
      "setLocalDescription",
      "createAnswer",
      "addTrack",
      "close",
    ]) {
      this[method] = vi.fn(FakeRTCPeerConnection.prototype[method].bind(this));
    }

    this.addEventListener = vi.fn();
    this.getStats = vi.fn(async () => new Map());
    this.connectionState = "connected";
    this.iceConnectionState = "connected";
  }
}

function pushWithReceivers() {
  const receivers = {};
  const push = {
    receive: vi.fn((status, callback) => {
      receivers[status] = callback;
      return push;
    }),
  };

  return { push, receivers };
}

function activityStats({
  bytesReceived = 0,
  bytesSent = 0,
  packetsReceived = 0,
  packetsSent = 0,
  messagesReceived = 0,
  messagesSent = 0,
} = {}) {
  return new Map([
    [
      "candidate-pair",
      {
        type: "candidate-pair",
        state: "succeeded",
        bytesReceived,
        bytesSent,
        packetsReceived,
        packetsSent,
      },
    ],
    [
      "data",
      {
        type: "data-channel",
        bytesReceived: 0,
        bytesSent: 0,
        messagesReceived,
        messagesSent,
      },
    ],
  ]);
}

describe("GroupCallWebRTCHook media fallback", () => {
  beforeEach(() => {
    vi.spyOn(HTMLMediaElement.prototype, "play").mockResolvedValue(undefined);
  });

  afterEach(() => {
    for (const hook of hooks) {
      hook._stopStatsPolling?.();
    }
    hooks = [];
    vi.useRealTimers();
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

    expect(hook.localStream).not.toBe(null);
    expect(hook.localStream.getTracks()).toEqual([]);
    expect(hook.pc.addTrack).not.toHaveBeenCalled();
    expect(hook.pushEvent).toHaveBeenCalledWith("group_call_client_warning", {
      code: "media_capture_failed",
      message: "Could not access your microphone or camera. You joined receive-only.",
    });
    expect(hook.pushEvent).not.toHaveBeenCalledWith("group_call_client_error", expect.anything());
  });

  it("builds capture constraints from pre-join device preferences", () => {
    const hook = setupHook();
    hook.mediaEnabled = { audio: true, video: true };
    hook.devicePreferences = {
      audioInputId: "mic-1",
      videoInputId: "cam-1",
      audioOutputId: "spk-1",
    };

    expect(hook._captureConstraints()).toEqual({
      audio: expect.objectContaining({ deviceId: { exact: "mic-1" } }),
      video: expect.objectContaining({ deviceId: { exact: "cam-1" } }),
    });
  });

  it("does not request browser media when pre-join disabled microphone and camera", async () => {
    const hook = setupHook();
    const emptyStream = { getTracks: vi.fn(() => []) };
    hook.mediaEnabled = { audio: false, video: false };
    hook._attachLocalStream = vi.fn();
    hook._applyMediaEnabled = vi.fn();

    vi.stubGlobal("MediaStream", function MediaStreamMock() {
      return emptyStream;
    });
    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getUserMedia: vi.fn(),
      },
    });

    await hook._ensureLocalTracks();

    expect(navigator.mediaDevices.getUserMedia).not.toHaveBeenCalled();
    expect(hook.localStream).toBe(emptyStream);
    expect(hook._attachLocalStream).toHaveBeenCalledWith(emptyStream);
  });

  it("acquires and publishes a missing microphone track when audio is enabled later", async () => {
    const hook = setupHook();
    const audioTrack = { id: "audio-late", kind: "audio", readyState: "live", enabled: true };
    const localTracks = [];
    const localStream = {
      addTrack: vi.fn((track) => localTracks.push(track)),
      getTracks: vi.fn(() => localTracks),
      getAudioTracks: vi.fn(() => localTracks.filter((track) => track.kind === "audio")),
      getVideoTracks: vi.fn(() => []),
    };
    const captureStream = {
      getTracks: vi.fn(() => [audioTrack]),
      getAudioTracks: vi.fn(() => [audioTrack]),
      getVideoTracks: vi.fn(() => []),
    };
    const pushResult = pushWithReceivers().push;

    hook.localStream = localStream;
    hook.mediaEnabled = { audio: false, video: false };
    hook.participantId = 12;
    hook.channel = { push: vi.fn(() => pushResult) };
    hook.pc = { addTrack: vi.fn((track) => ({ track })) };

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getUserMedia: vi.fn().mockResolvedValue(captureStream),
      },
    });

    hook._publishLocalMediaState({ audio: true, video: false });

    await vi.waitFor(() => {
      expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalled();
      expect(hook.pc.addTrack).toHaveBeenCalledWith(audioTrack, localStream);
      expect(hook.channel.push).toHaveBeenCalledWith("group_call_request_offer", {
        attempt: 0,
        trigger: "local_media_added",
      });
      expect(hook.channel.push).toHaveBeenCalledWith("group_call_media_state", {
        audio: true,
        video: false,
      });
    });
  });

  it("keeps the local tile empty-state copy synchronized with live media state", () => {
    const hook = setupLayoutHook();
    const localTile = hook.el.querySelector("[data-group-call-local-tile]");
    const title = hook.el.querySelector("[data-group-call-local-empty-title]");
    const detail = hook.el.querySelector("[data-group-call-local-empty-detail]");

    hook.mediaEnabled = { audio: false, video: false };
    hook._syncLocalTile();

    expect(localTile.dataset.localEmptyState).toBe("receive-only");
    expect(title.textContent).toBe("Receive-only mode");
    expect(detail.textContent).toBe("Your microphone and camera are off.");

    hook.mediaEnabled = { audio: true, video: false };
    hook._syncLocalTile();

    expect(localTile.dataset.localEmptyState).toBe("camera-off");
    expect(title.textContent).toBe("Camera off");
    expect(detail.textContent).toBe("Your camera is not being sent.");

    hook.screenShare = { active: true };
    hook._syncLocalTile();

    expect(localTile.dataset.localEmptyState).toBe("screen-share");
    expect(title.textContent).toBe("Sharing screen");
    expect(detail.textContent).toBe("Your screen is replacing the camera feed.");
  });

  it("applies server-forced camera moderation to local media tracks", () => {
    const hook = setupHook();
    const audioTrack = { kind: "audio", enabled: true };
    const videoTrack = { kind: "video", enabled: true };

    hook.participantId = 123;
    hook.localStream = {
      getAudioTracks: vi.fn(() => [audioTrack]),
      getVideoTracks: vi.fn(() => [videoTrack]),
    };
    hook._syncLocalTile = vi.fn();

    hook._setMediaState({
      audio: true,
      video: false,
      server_video_blocked: true,
    });

    expect(audioTrack.enabled).toBe(true);
    expect(videoTrack.enabled).toBe(false);
    expect(hook.mediaEnabled).toEqual({ audio: true, video: false });
    expect(hook._syncLocalTile).toHaveBeenCalled();
    expect(hook.channel.push).toHaveBeenCalledWith("group_call_media_state", {
      audio: true,
      video: false,
    });
  });

  it("preserves server media moderation across partial local media updates", () => {
    const hook = setupHook();
    const audioTrack = { kind: "audio", enabled: true };
    const videoTrack = { kind: "video", enabled: true };

    hook.participantId = 123;
    hook.localStream = {
      getAudioTracks: vi.fn(() => [audioTrack]),
      getVideoTracks: vi.fn(() => [videoTrack]),
    };
    hook._syncLocalTile = vi.fn();

    hook._setMediaState({
      audio: false,
      video: true,
      server_audio_muted: true,
      server_screen_blocked: true,
    });
    hook._setMediaState({ audio: true, video: true });

    expect(hook.serverAudioMuted).toBe(true);
    expect(hook.screenShareBlocked).toBe(true);
    expect(audioTrack.enabled).toBe(false);
    expect(videoTrack.enabled).toBe(true);
    expect(hook.mediaEnabled).toEqual({ audio: false, video: true });
  });

  it("push-to-talk enables the real audio track while held and restores mute on release", () => {
    const hook = setupHook();
    const audioTrack = { kind: "audio", enabled: false, readyState: "live" };
    const videoTrack = { kind: "video", enabled: true, readyState: "live" };

    hook.participantId = 123;
    hook.mediaEnabled = { audio: false, video: true };
    hook.localStream = {
      getAudioTracks: vi.fn(() => [audioTrack]),
      getVideoTracks: vi.fn(() => [videoTrack]),
    };
    hook._syncLocalTile = vi.fn();

    const keydown = new KeyboardEvent("keydown", {
      key: "Z",
      ctrlKey: true,
      shiftKey: true,
      bubbles: true,
      cancelable: true,
    });
    const keyup = new KeyboardEvent("keyup", {
      key: "Z",
      ctrlKey: true,
      shiftKey: true,
      bubbles: true,
      cancelable: true,
    });

    hook._handlePushToTalkKeydown(keydown);

    expect(keydown.defaultPrevented).toBe(true);
    expect(hook.pushToTalkActive).toBe(true);
    expect(audioTrack.enabled).toBe(true);
    expect(hook.channel.push).toHaveBeenLastCalledWith("group_call_media_state", {
      audio: true,
      video: true,
    });
    expect(hook.pushEvent).toHaveBeenLastCalledWith("group_call_media_state_forced", {
      audio: true,
      video: true,
    });

    hook._handlePushToTalkKeyup(keyup);

    expect(keyup.defaultPrevented).toBe(true);
    expect(hook.pushToTalkActive).toBe(false);
    expect(audioTrack.enabled).toBe(false);
    expect(hook.channel.push).toHaveBeenLastCalledWith("group_call_media_state", {
      audio: false,
      video: true,
    });
    expect(hook.pushEvent).toHaveBeenLastCalledWith("group_call_media_state_forced", {
      audio: false,
      video: true,
    });
  });

  it("does not push-to-talk from editable fields", () => {
    const hook = setupHook();
    const input = document.createElement("input");
    const audioTrack = { kind: "audio", enabled: false, readyState: "live" };
    const event = {
      key: "Z",
      ctrlKey: true,
      shiftKey: true,
      altKey: false,
      metaKey: false,
      defaultPrevented: false,
      repeat: false,
      target: input,
      preventDefault: vi.fn(),
      stopPropagation: vi.fn(),
    };

    hook.participantId = 123;
    hook.mediaEnabled = { audio: false, video: true };
    hook.localStream = {
      getAudioTracks: vi.fn(() => [audioTrack]),
      getVideoTracks: vi.fn(() => []),
    };
    hook._syncLocalTile = vi.fn();

    hook._handlePushToTalkKeydown(event);

    expect(audioTrack.enabled).toBe(false);
    expect(event.preventDefault).not.toHaveBeenCalled();
    expect(hook.channel.push).not.toHaveBeenCalled();
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
      sdp: expect.any(String),
      offer_id: null,
    });
  });

  it("echoes offer_id in the SDP answer and ignores repeats by id", async () => {
    const hook = setupNegotiationHook();
    const pc = new MockPeerConnection();
    vi.stubGlobal("RTCPeerConnection", function RTCPeerConnectionMock() {
      return pc;
    });

    await hook._handleOffer({ sdp: "offer-sdp-v1", ice_servers: [], offer_id: "gc-12-1" });
    await hook._handleOffer({ sdp: "offer-sdp-v1", ice_servers: [], offer_id: "gc-12-1" });

    expect(pc.setRemoteDescription).toHaveBeenCalledTimes(1);
    expect(hook.channel.push).toHaveBeenCalledTimes(1);
    expect(hook.channel.push).toHaveBeenCalledWith("group_call_answer", {
      sdp: expect.any(String),
      offer_id: "gc-12-1",
    });
  });

  it("answers an offer when sender profile caps are rejected by the browser", async () => {
    const hook = setupHook();
    hook.pc = null;
    const audioTrack = { kind: "audio", enabled: true, contentHint: "" };
    const videoTrack = { kind: "video", enabled: true, contentHint: "" };
    const stream = {
      getTracks: vi.fn(() => [audioTrack, videoTrack]),
      getAudioTracks: vi.fn(() => [audioTrack]),
      getVideoTracks: vi.fn(() => [videoTrack]),
    };
    const senders = [];
    const pc = new MockPeerConnection();

    pc.addTrack = vi.fn((track) => {
      const sender = {
        track,
        getParameters: vi.fn(() => ({ encodings: [{}] })),
        setParameters: vi.fn().mockRejectedValue(new DOMException("busy", "InvalidStateError")),
      };
      senders.push(sender);
      return sender;
    });
    pc.getSenders = vi.fn(() => senders);

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getUserMedia: vi.fn().mockResolvedValue(stream),
      },
    });
    vi.stubGlobal("RTCPeerConnection", function RTCPeerConnectionMock() {
      return pc;
    });

    await hook._handleOffer({ sdp: "offer-sdp", ice_servers: [] });

    expect(pc.createAnswer).toHaveBeenCalled();
    expect(hook.channel.push).toHaveBeenCalledWith("group_call_answer", {
      sdp: expect.any(String),
      offer_id: null,
    });
    expect(hook.pushEvent).not.toHaveBeenCalledWith(
      "group_call_client_error",
      expect.objectContaining({ code: "media_negotiation_failed" }),
    );
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

  it("backs off and asks the SFU for a fresh offer when media disconnects", async () => {
    vi.useFakeTimers();
    const hook = setupHook();
    const pushResult = {
      receive: vi.fn(() => pushResult),
    };
    hook.channel = { push: vi.fn(() => pushResult) };
    hook.pc = { connectionState: "disconnected" };

    hook._handleConnectionStateChange();

    expect(hook.pushEvent).toHaveBeenCalledWith("group_call_connection_state", {
      state: "disconnected",
    });
    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_recovery_state",
      expect.objectContaining({
        state: "reconnecting",
        attempt: 1,
        max_attempts: 3,
        next_retry_ms: 1000,
      }),
    );

    await vi.advanceTimersByTimeAsync(1000);

    expect(hook.channel.push).toHaveBeenCalledWith("group_call_request_offer", {
      attempt: 1,
      trigger: "auto",
    });
  });

  it("defers disconnected recovery while getStats still shows activity", async () => {
    vi.useFakeTimers();
    const hook = setupHook();
    const pushResult = {
      receive: vi.fn(() => pushResult),
    };
    const statsQueue = [
      activityStats({ bytesReceived: 100, bytesSent: 50, packetsReceived: 2, packetsSent: 1 }),
      activityStats({ bytesReceived: 200, bytesSent: 50, packetsReceived: 3, packetsSent: 1 }),
      activityStats({ bytesReceived: 200, bytesSent: 50, packetsReceived: 3, packetsSent: 1 }),
    ];
    hook.channel = { push: vi.fn(() => pushResult) };
    hook.pc = {
      connectionState: "disconnected",
      getStats: vi.fn(async () => statsQueue.shift() || activityStats()),
    };

    hook._handleConnectionStateChange();
    await vi.advanceTimersByTimeAsync(1000);

    expect(hook.channel.push).not.toHaveBeenCalledWith(
      "group_call_request_offer",
      expect.any(Object),
    );

    await vi.advanceTimersByTimeAsync(1000);

    expect(hook.channel.push).toHaveBeenCalledWith("group_call_request_offer", {
      attempt: 1,
      trigger: "auto",
    });
  });

  it("uses ICE failed as a group-call recovery signal", async () => {
    vi.useFakeTimers();
    const hook = setupHook();
    const pushResult = {
      receive: vi.fn(() => pushResult),
    };
    hook.channel = { push: vi.fn(() => pushResult) };
    hook.pc = { connectionState: "connected", iceConnectionState: "failed" };

    hook._handleIceConnectionStateChange();

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_recovery_state",
      expect.objectContaining({
        state: "reconnecting",
        reason: "ice_failed",
        attempt: 1,
      }),
    );

    await vi.advanceTimersByTimeAsync(1000);

    expect(hook.channel.push).toHaveBeenCalledWith("group_call_request_offer", {
      attempt: 1,
      trigger: "auto",
    });
  });

  it("requests a fresh offer when the initial group-call offer is not received", async () => {
    vi.useFakeTimers();
    const hook = setupHook();
    const pushResult = {
      receive: vi.fn(() => pushResult),
    };

    hook.channel = { push: vi.fn(() => pushResult) };

    hook._handleJoined({ participants: [], tracks: [] });
    hook.pushEvent.mockClear();

    await vi.advanceTimersByTimeAsync(1500);

    expect(hook.channel.push).toHaveBeenCalledWith("group_call_request_offer", {
      attempt: 1,
      trigger: "offer_watchdog",
      reason: "join",
    });
    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_recovery_state",
      expect.objectContaining({
        state: "reconnecting",
        reason: "offer_not_received",
        trigger: "offer_watchdog",
        attempt: 1,
      }),
    );

    await vi.advanceTimersByTimeAsync(3000);
    await vi.advanceTimersByTimeAsync(4500);
    await vi.advanceTimersByTimeAsync(1500);

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_recovery_state",
      expect.objectContaining({
        state: "failed",
        reason: "offer_not_received",
        trigger: "offer_watchdog",
        manual_retry: true,
      }),
    );
  });

  it("does not request offer replay when an offer is already applied", async () => {
    vi.useFakeTimers();
    const hook = setupHook();
    const pushResult = {
      receive: vi.fn(() => pushResult),
    };

    hook.channel = { push: vi.fn(() => pushResult) };
    hook.pc = { remoteDescription: { type: "offer", sdp: "offer-sdp" } };

    hook._handleJoined({ participants: [], tracks: [] });
    hook.pushEvent.mockClear();

    await vi.advanceTimersByTimeAsync(5000);

    expect(hook.channel.push).not.toHaveBeenCalledWith(
      "group_call_request_offer",
      expect.any(Object),
    );
  });

  it("recovers after repeated remote ICE candidate failures and resets on success", async () => {
    vi.useFakeTimers();
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const hook = setupHook();
    const candidate = { candidate: "bad-candidate", sdpMid: "0", sdpMLineIndex: 0 };

    hook.pc = {
      remoteDescription: { type: "offer", sdp: "remote" },
      addIceCandidate: vi
        .fn()
        .mockRejectedValueOnce(new Error("m-line mismatch"))
        .mockRejectedValueOnce(new Error("m-line mismatch"))
        .mockResolvedValueOnce(undefined)
        .mockRejectedValue(new Error("m-line mismatch")),
    };
    hook.pushEvent.mockClear();

    await hook._handleRemoteCandidate(candidate);
    await hook._handleRemoteCandidate(candidate);

    expect(hook.pushEvent).not.toHaveBeenCalledWith(
      "group_call_recovery_state",
      expect.objectContaining({ reason: "ice_candidate_failed" }),
    );

    await hook._handleRemoteCandidate(candidate);
    await hook._handleRemoteCandidate(candidate);
    await hook._handleRemoteCandidate(candidate);

    expect(hook.pushEvent).not.toHaveBeenCalledWith(
      "group_call_recovery_state",
      expect.objectContaining({ reason: "ice_candidate_failed" }),
    );

    await hook._handleRemoteCandidate(candidate);

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_recovery_state",
      expect.objectContaining({
        state: "reconnecting",
        reason: "ice_candidate_failed",
        attempt: 1,
      }),
    );
  });

  it("requests a fresh offer when a remote video tile stops rendering", () => {
    const hook = setupHook();
    const pushResult = {
      receive: vi.fn(() => pushResult),
    };
    hook.channel = { push: vi.fn(() => pushResult) };

    hook._handleRemoteVideoStalled("stream-456", "no-video-dimensions");

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_recovery_state",
      expect.objectContaining({
        state: "reconnecting",
        reason: "no-video-dimensions",
        trigger: "remote_video_stalled",
      }),
    );
    expect(hook.channel.push).toHaveBeenCalledWith("group_call_request_offer", {
      attempt: 1,
      trigger: "remote_video_stalled",
    });

    hook._handleRemoteVideoStalled("stream-456", "not-ready");

    expect(hook.channel.push).toHaveBeenCalledTimes(1);
  });

  it("requests a fresh offer immediately when manual retry is triggered", () => {
    const hook = setupHook();
    const pushResult = {
      receive: vi.fn(() => pushResult),
    };
    hook.channel = { push: vi.fn(() => pushResult) };

    hook._retryConnection("manual");

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_recovery_state",
      expect.objectContaining({ state: "negotiating", trigger: "manual" }),
    );
    expect(hook.channel.push).toHaveBeenCalledWith("group_call_request_offer", {
      attempt: 1,
      trigger: "manual",
    });
  });

  it("rejoins the SFU media endpoint when request_offer reports peer_not_ready", () => {
    const hook = setupLayoutHook();
    const requestOffer = pushWithReceivers();
    const rejoin = pushWithReceivers();
    const pc = { close: vi.fn(), connectionState: "failed" };

    hook.participantId = 42;
    hook.recoveryAttempts = 1;
    hook.pc = pc;
    const oldTile = hook.tileView.ensure("old-stream");
    hook.trackRegistry.upsert({ id: "track-1" });
    hook.channel = {
      push: vi.fn((event) => {
        if (event === "group_call_request_offer") return requestOffer.push;
        if (event === "group_call_join") return rejoin.push;
        return pushWithReceivers().push;
      }),
    };

    hook._retryConnection("manual");
    requestOffer.receivers.error({
      code: "rejoin_required",
      message: "Media endpoint must rejoin",
    });

    expect(pc.close).toHaveBeenCalled();
    expect(oldTile.isConnected).toBe(false);
    expect(hook.rejoinEpoch).toBe(1);
    expect(hook.pc).toBeNull();
    expect(hook.trackRegistry.size).toBe(0);
    expect(hook.channel.push).toHaveBeenCalledWith(
      "group_call_join",
      expect.objectContaining({
        trigger: "rejoin",
        previous_participant_id: 42,
        rejoin_epoch: 1,
      }),
    );
    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_recovery_state",
      expect.objectContaining({ state: "rejoining", trigger: "manual" }),
    );
  });

  it("republishes existing local tracks on a newly created peer connection", async () => {
    const hook = setupNegotiationHook();
    const audioTrack = { id: "audio-1", kind: "audio", enabled: true };
    const stream = {
      getTracks: vi.fn(() => [audioTrack]),
      getAudioTracks: vi.fn(() => [audioTrack]),
      getVideoTracks: vi.fn(() => []),
    };
    const pc = new MockPeerConnection();

    hook.localStream = stream;
    hook._sendersPc = { old: true };
    vi.stubGlobal("RTCPeerConnection", function RTCPeerConnectionMock() {
      return pc;
    });

    await hook._processOffer({ sdp: "offer-after-rejoin", ice_servers: [] });

    expect(pc.addTrack).toHaveBeenCalledWith(audioTrack, stream);
    expect(hook._sendersPc).toBe(pc);
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
    });

    const videoAfterFocus = hook.el.querySelector('[data-stream-id="stream-456"] video');
    expect(videoAfterFocus).toBe(video);
    expect(videoAfterFocus.srcObject).toBe(stream);
    expect(tile.dataset.focused).toBe("true");
  });

  it("watches remote video tiles for stalled rendering and requests recovery", async () => {
    vi.useFakeTimers();
    const hook = setupLayoutHook();
    const pushResult = {
      receive: vi.fn(() => pushResult),
    };
    const videoTrack = { id: "track-456", kind: "video", readyState: "live", muted: false };
    const stream = {
      id: "stream-456",
      getTracks: vi.fn(() => [videoTrack]),
      getAudioTracks: vi.fn(() => []),
      getVideoTracks: vi.fn(() => [videoTrack]),
    };

    hook.channel = { push: vi.fn(() => pushResult) };
    hook._syncLayoutState({
      participants: [{ id: 456, nickname: "Ada", media_state: { audio: true, video: true } }],
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

    hook._attachRemoteStream(stream, videoTrack);
    await Promise.resolve();
    await vi.advanceTimersByTimeAsync(1800);

    expect(hook.channel.push).toHaveBeenCalledWith("group_call_request_offer", {
      attempt: 1,
      trigger: "remote_video_stalled",
    });
    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_recovery_state",
      expect.objectContaining({
        state: "reconnecting",
        trigger: "remote_video_stalled",
      }),
    );
  });

  it("builds remote tiles from the rendered icon template", () => {
    const hook = setupLayoutHook();
    const tile = hook.tileView.ensure("stream-icons");

    expect(tile.querySelector('[data-test-icon="remote-microphone"]')).not.toBeNull();
    expect(tile.querySelector('[data-test-icon="remote-camera"]')).not.toBeNull();
    expect(tile.querySelector("[data-group-call-audio-badge]")?.textContent.trim()).toBe("");
    expect(tile.querySelector("[data-group-call-video-badge]")?.textContent.trim()).toBe("");
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

  it("speaker layout follows the active speaker without replacing remote videos", () => {
    const hook = setupLayoutHook();

    hook._syncLayoutState({
      participants: [
        { id: 456, nickname: "Ada", media_state: { audio: true, video: true } },
        { id: 789, nickname: "Grace", media_state: { audio: true, video: true } },
      ],
      tracks: [
        { id: 2, participant_id: 456, stream_id: "stream-456" },
        { id: 3, participant_id: 789, stream_id: "stream-789" },
      ],
    });
    hook._attachRemoteStream({ id: "stream-456" });
    hook._attachRemoteStream({ id: "stream-789" });

    const adaTile = hook.el.querySelector('[data-stream-id="stream-456"]');
    const graceTile = hook.el.querySelector('[data-stream-id="stream-789"]');
    const adaVideo = adaTile.querySelector("video");
    const graceVideo = graceTile.querySelector("video");

    hook._syncLayoutState({ mode: "speaker", focused_participant_id: 456 });

    expect(hook.el.dataset.layoutMode).toBe("speaker");
    expect(adaTile.dataset.focused).toBe("true");

    hook._syncParticipantQualityState({
      active_speaker_participant_id: "789",
      participants: [
        { participant_id: "456", level: "good", speaking: false },
        { participant_id: "789", level: "excellent", speaking: true },
      ],
    });

    expect(adaTile.dataset.focused).toBe("false");
    expect(graceTile.dataset.focused).toBe("true");
    expect(adaTile.querySelector("video")).toBe(adaVideo);
    expect(graceTile.querySelector("video")).toBe(graceVideo);
  });

  it("marks pinned participants and switches to dense tile layout for larger grids", () => {
    const hook = setupLayoutHook();
    const host = hook.el.querySelector("[data-group-call-video-grid]");
    const participants = [456, 789, 901, 902].map((id) => ({
      id,
      nickname: `User${id}`,
      media_state: { audio: true, video: true },
    }));

    hook._syncLayoutState({
      participants,
      tracks: participants.map((participant) => ({
        id: participant.id,
        participant_id: participant.id,
        stream_id: `stream-${participant.id}`,
      })),
    });

    for (const participant of participants) {
      hook._attachRemoteStream({ id: `stream-${participant.id}` });
    }

    hook._syncLayoutState({ mode: "grid", pinned_participant_ids: [456, "789"] });

    expect(host.dataset.tileCount).toBe("5");
    expect(host.dataset.tileDensity).toBe("dense");
    expect(hook.el.querySelector('[data-stream-id="stream-456"]').dataset.pinned).toBe("true");
    expect(hook.el.querySelector('[data-stream-id="stream-789"]').dataset.pinned).toBe("true");

    hook._syncLayoutState({ pinned_participant_ids: ["789"] });

    expect(hook.el.querySelector('[data-stream-id="stream-456"]').dataset.pinned).toBe("false");
    expect(hook.el.querySelector('[data-stream-id="stream-789"]').dataset.pinned).toBe("true");
  });

  it("sends conference reactions through the signaling channel", () => {
    const hook = setupLayoutHook();
    const receiveChain = { receive: vi.fn(() => receiveChain) };
    hook.channel = { push: vi.fn(() => receiveChain) };

    hook._sendReaction("heart");

    expect(hook.channel.push).toHaveBeenCalledWith("group_call_reaction", {
      reaction: "heart",
    });
  });

  it("renders and expires reaction overlays on participant tiles", () => {
    vi.useFakeTimers();
    const hook = setupLayoutHook();

    hook._syncLayoutState({
      participants: [{ id: 456, nickname: "Ada", media_state: { audio: true, video: true } }],
      tracks: [{ id: 2, participant_id: 456, stream_id: "stream-456" }],
    });
    hook._attachRemoteStream({ id: "stream-456" });

    hook._applyReaction({
      id: "reaction-1",
      participant_id: 456,
      reaction: "clap",
      emoji: "👏",
    });

    const tile = hook.el.querySelector('[data-stream-id="stream-456"]');
    expect(
      tile.querySelector('[data-group-call-reaction-bubble][data-reaction="clap"]'),
    ).not.toBeNull();
    expect(
      tile.querySelector(
        '[data-group-call-reaction-bubble][data-reaction="clap"] [data-test-icon="reaction-clap"]',
      ),
    ).not.toBeNull();
    expect(
      tile.querySelector('[data-group-call-reaction-bubble][data-reaction="clap"]').textContent,
    ).toBe("");

    vi.advanceTimersByTime(2400);

    expect(tile.querySelector("[data-group-call-reaction-bubble]")).toBeNull();
  });

  it("pushes live browser stats with conference counters", async () => {
    const hook = setupLayoutHook();
    hook.pc = {
      connectionState: "connected",
      getStats: vi.fn(async () => new Map()),
    };
    hook.participantRegistry.upsert({ id: "123" });
    hook.tileView.ensure("stream-456");
    hook.trackRegistry.upsert({ id: "track-1" });
    hook.lastAnsweredOfferId = "gc-12-1";
    hook.rejoinEpoch = 2;

    await hook._sampleStats();

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_stats",
      expect.objectContaining({
        connection_state: "connected",
        summary: expect.objectContaining({
          connection_state: "connected",
          participant_count: 1,
          remote_stream_count: 1,
          track_count: 1,
          screen_share_active: false,
          offer_id: "gc-12-1",
          rejoin_epoch: 2,
        }),
      }),
    );
  });

  it("derives active speaker and participant quality from remote media stats", async () => {
    const hook = setupLayoutHook();

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
          kind: "audio",
          status: "active",
          webrtc_track_id: "audio-track-456",
        },
        {
          id: 2,
          participant_id: 456,
          kind: "video",
          status: "active",
          stream_id: "stream-456",
          webrtc_track_id: "video-track-456",
        },
      ],
    });
    hook._attachRemoteStream(
      { id: "stream-456" },
      { id: "video-track-456", kind: "video", readyState: "live" },
    );
    hook.pc = {
      connectionState: "connected",
      getStats: vi.fn(async () => {
        return new Map([
          [
            "candidate-pair",
            {
              type: "candidate-pair",
              state: "succeeded",
              currentRoundTripTime: 0.08,
              availableOutgoingBitrate: 1_800_000,
            },
          ],
          [
            "inbound-audio",
            {
              type: "inbound-rtp",
              kind: "audio",
              trackIdentifier: "audio-track-456",
              bytesReceived: 16_000,
              packetsLost: 0,
              packetsReceived: 180,
              jitter: 0.006,
              audioLevel: 0.08,
            },
          ],
          [
            "inbound-video",
            {
              type: "inbound-rtp",
              kind: "video",
              trackIdentifier: "video-track-456",
              bytesReceived: 280_000,
              packetsLost: 0,
              packetsReceived: 420,
              jitter: 0.004,
              framesPerSecond: 30,
              frameWidth: 1280,
              frameHeight: 720,
              freezeCount: 0,
            },
          ],
        ]);
      }),
    };

    await hook._sampleStats();

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_participant_quality",
      expect.objectContaining({
        active_speaker_participant_id: "456",
        participants: [
          expect.objectContaining({
            participant_id: "456",
            level: "excellent",
            speaking: true,
            rtt_ms: 80,
            jitter_ms: 6,
            fps: 30,
          }),
        ],
      }),
    );

    const tile = hook.el.querySelector('[data-stream-id="stream-456"]');
    const qualityBadge = tile.querySelector("[data-group-call-quality-badge]");
    expect(tile.dataset.activeSpeaker).toBe("true");
    expect(tile.dataset.qualityLevel).toBe("excellent");
    expect(qualityBadge.hidden).toBe(false);
    expect(qualityBadge.title).toContain("Excellent");
  });

  it("accepts an instrumented participant quality event for deterministic UI checks", () => {
    const hook = setupLayoutHook();

    hook._syncLayoutState({
      participants: [
        {
          id: 456,
          nickname: "Ada",
          status: "connected",
          media_state: { audio: true, video: true },
        },
      ],
      tracks: [{ id: 2, participant_id: 456, stream_id: "stream-456" }],
    });
    hook._attachRemoteStream({ id: "stream-456" });
    const tileBeforeQuality = hook.el.querySelector('[data-stream-id="stream-456"]');
    expect(tileBeforeQuality.querySelector("[data-group-call-quality-badge]").hidden).toBe(true);

    hook.participantQualityEventHandler = (event) => {
      const payload = event.detail || {};
      hook._syncParticipantQualityState(payload);
      hook.pushEvent("group_call_participant_quality", payload);
    };
    hook.el.addEventListener("group-call:participant-quality", hook.participantQualityEventHandler);

    hook.el.dispatchEvent(
      new CustomEvent("group-call:participant-quality", {
        detail: {
          active_speaker_participant_id: "456",
          participants: [
            {
              participant_id: "456",
              level: "poor",
              speaking: true,
              rtt_ms: 260,
              jitter_ms: 55,
              loss_pct: 8.5,
              bitrate_kbps: 240,
              fps: 12,
              freeze_count: 3,
            },
          ],
        },
      }),
    );

    const tile = hook.el.querySelector('[data-stream-id="stream-456"]');
    const qualityBadge = tile.querySelector("[data-group-call-quality-badge]");
    expect(tile.dataset.activeSpeaker).toBe("true");
    expect(tile.dataset.qualityLevel).toBe("poor");
    expect(qualityBadge.hidden).toBe(false);
    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_participant_quality",
      expect.objectContaining({ active_speaker_participant_id: "456" }),
    );
  });

  it("starts and stops screen sharing by replacing the published video track", async () => {
    const hook = setupLayoutHook();
    const cameraTrack = { id: "camera-track", kind: "video", readyState: "live" };
    const screenTrack = {
      id: "screen-track",
      kind: "video",
      contentHint: "",
      readyState: "live",
      stop: vi.fn(() => {
        screenTrack.readyState = "ended";
      }),
      onended: null,
    };
    const screenStream = {
      id: "screen-stream",
      getVideoTracks: vi.fn(() => [screenTrack]),
      getTracks: vi.fn(() => [screenTrack]),
    };
    const sender = {
      track: cameraTrack,
      replaceTrack: vi.fn(async (track) => {
        sender.track = track;
      }),
      getParameters: vi.fn(() => ({ encodings: [{}] })),
      setParameters: vi.fn(),
    };

    hook.participantId = 123;
    hook.localStream = { id: "camera-stream", getTracks: vi.fn(() => [cameraTrack]) };
    hook.cameraVideoTrack = cameraTrack;
    hook.videoSender = sender;

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getDisplayMedia: vi.fn().mockResolvedValue(screenStream),
      },
    });

    await hook._startScreenShare();

    const localVideo = hook.el.querySelector("[data-group-call-local-video]");
    const localTile = hook.el.querySelector("[data-group-call-local-tile]");

    expect(navigator.mediaDevices.getDisplayMedia).toHaveBeenCalledWith({
      video: {
        width: { max: 1280 },
        height: { max: 720 },
        frameRate: { ideal: 5, max: 10 },
      },
      audio: false,
    });
    expect(sender.replaceTrack).toHaveBeenCalledWith(screenTrack);
    expect(sender.setParameters.mock.calls[0][0].encodings[0]).toEqual(
      expect.objectContaining({ maxBitrate: 800_000, maxFramerate: 10 }),
    );
    expect(screenTrack.contentHint).toBe("detail");
    expect(localVideo.srcObject).toBe(screenStream);
    expect(localTile.dataset.mediaScreen).toBe("true");
    expect(localTile.dataset.trackSource).toBe("screen");
    expect(hook.channel.push).toHaveBeenCalledWith(
      "group_call_screen_share_state",
      expect.objectContaining({
        active: true,
        participant_id: 123,
        track_id: "screen-track",
        stream_id: "screen-stream",
      }),
    );
    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_screen_share_state",
      expect.objectContaining({ active: true }),
    );

    await hook._stopScreenShare("browser_ended");

    expect(sender.replaceTrack).toHaveBeenLastCalledWith(cameraTrack);
    expect(sender.setParameters.mock.calls.at(-1)[0].encodings[0]).toEqual(
      expect.objectContaining({ maxBitrate: 400_000, maxFramerate: 15 }),
    );
    expect(screenTrack.stop).toHaveBeenCalled();
    expect(localVideo.srcObject).toBe(hook.localStream);
    expect(localTile.dataset.mediaScreen).toBe("false");
    expect(localTile.dataset.trackSource).toBe("camera");
    expect(hook.channel.push).toHaveBeenLastCalledWith(
      "group_call_screen_share_state",
      expect.objectContaining({
        active: false,
        reason: "browser_ended",
      }),
    );
  });

  it("does not start screen sharing while blocked by moderation", async () => {
    const hook = setupLayoutHook();
    hook.screenShareBlocked = true;

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getDisplayMedia: vi.fn(),
      },
    });

    await hook._startScreenShare();

    expect(navigator.mediaDevices.getDisplayMedia).not.toHaveBeenCalled();
    expect(hook.pushEvent).toHaveBeenCalledWith(
      "group_call_client_warning",
      expect.objectContaining({
        code: "screen_share_moderated",
      }),
    );
  });

  it("stops active screen sharing when a moderator blocks it", async () => {
    const hook = setupLayoutHook();
    const cameraTrack = { id: "camera-track", kind: "video", readyState: "live" };
    const screenTrack = {
      id: "screen-track",
      kind: "video",
      readyState: "live",
      stop: vi.fn(() => {
        screenTrack.readyState = "ended";
      }),
      onended: vi.fn(),
    };
    const screenStream = {
      id: "screen-stream",
      getTracks: vi.fn(() => [screenTrack]),
    };
    const sender = {
      track: screenTrack,
      replaceTrack: vi.fn(async (track) => {
        sender.track = track;
      }),
      getParameters: vi.fn(() => ({ encodings: [{}] })),
      setParameters: vi.fn(),
    };

    hook.participantId = 123;
    hook.localStream = { id: "camera-stream", getTracks: vi.fn(() => [cameraTrack]) };
    hook.cameraVideoTrack = cameraTrack;
    hook.videoSender = sender;
    hook.screenShare = { active: true, stream: screenStream, track: screenTrack };

    await hook._stopScreenShareByModerator({
      reason: "moderation",
      server_screen_blocked: true,
    });

    expect(hook.screenShareBlocked).toBe(true);
    expect(sender.replaceTrack).toHaveBeenCalledWith(cameraTrack);
    expect(sender.setParameters.mock.calls.at(-1)[0].encodings[0]).toEqual(
      expect.objectContaining({ maxBitrate: 400_000, maxFramerate: 15 }),
    );
    expect(screenTrack.stop).toHaveBeenCalled();
    expect(hook.channel.push).toHaveBeenCalledWith(
      "group_call_screen_share_state",
      expect.objectContaining({
        active: false,
        reason: "moderation",
      }),
    );
  });

  it("marks remote screen-share tracks with a dedicated source and nameplate", () => {
    const hook = setupLayoutHook();

    hook._syncLayoutState({
      participants: [
        {
          id: 456,
          nickname: "Ada",
          status: "connected",
          media_state: { audio: true, video: true, screen: true },
        },
      ],
      tracks: [
        {
          id: 3,
          participant_id: 456,
          kind: "video",
          source: "screen",
          status: "active",
          stream_id: "screen-stream-456",
          webrtc_track_id: "screen-track-456",
        },
      ],
    });

    hook._attachRemoteStream({ id: "screen-stream-456" }, { id: "screen-track-456" });

    const tile = hook.el.querySelector('[data-stream-id="screen-stream-456"]');

    expect(tile.dataset.trackSource).toBe("screen");
    expect(tile.dataset.mediaScreen).toBe("true");
    expect(tile.querySelector("[data-group-call-tile-name]").textContent).toBe("Ada's screen");
  });

  it("applies screen-share state to the sole unassigned remote tile", () => {
    const hook = setupLayoutHook();

    hook._syncLayoutState({
      participants: [
        {
          id: 456,
          nickname: "Ada",
          status: "connected",
          media_state: { audio: true, video: true, screen: true },
        },
      ],
    });
    hook._attachRemoteStream({ id: "sfu-generated-stream" }, { id: "sfu-generated-track" });

    hook._applyScreenShareStateToTiles({
      active: true,
      participant_id: 456,
    });

    const tile = hook.el.querySelector('[data-stream-id="sfu-generated-stream"]');

    expect(tile.dataset.participantId).toBe("456");
    expect(tile.dataset.trackSource).toBe("screen");
    expect(tile.dataset.mediaScreen).toBe("true");
    expect(tile.querySelector("[data-group-call-tile-name]").textContent).toBe("Ada's screen");

    hook._applyScreenShareStateToTiles({
      active: false,
      participant_id: 456,
    });

    expect(tile.dataset.trackSource).toBe("camera");
    expect(tile.dataset.mediaScreen).toBe("false");
    expect(tile.querySelector("[data-group-call-tile-name]").textContent).toBe("Ada");
  });
});
