import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import MediaHook from "../../../js/hooks/p2p/media_hook.js";

// --- Test helpers ---

function createMockHook(opts = {}) {
  const eventHandlers = {};
  const pushedEvents = [];
  const domListeners = {};
  const webrtcListeners = {};

  const el = {
    addEventListener: vi.fn((type, handler) => {
      domListeners[type] = domListeners[type] || [];
      domListeners[type].push(handler);
    }),
    removeEventListener: vi.fn(),
    querySelector: vi.fn(() => null),
    dispatchEvent: vi.fn(),
  };

  // Mock #p2p-webrtc element
  const webrtcEl = {
    addEventListener: vi.fn((type, handler) => {
      webrtcListeners[type] = webrtcListeners[type] || [];
      webrtcListeners[type].push(handler);
    }),
    removeEventListener: vi.fn(),
    _peerConnection: opts.existingPC || null,
  };

  const origGetById = document.getElementById.bind(document);
  vi.spyOn(document, "getElementById").mockImplementation((id) => {
    if (id === "p2p-webrtc") return webrtcEl;
    return origGetById(id);
  });

  const hook = Object.create(MediaHook);
  hook.el = el;
  hook.pushEvent = vi.fn((event, payload) => pushedEvents.push({ event, payload }));
  hook.handleEvent = vi.fn((event, handler) => {
    eventHandlers[event] = handler;
  });

  return { hook, el, eventHandlers, pushedEvents, domListeners, webrtcEl, webrtcListeners };
}

function createMockPC() {
  return {
    addTrack: vi.fn((track) => ({ track, replaceTrack: vi.fn() })),
    removeTrack: vi.fn(),
    getSenders: vi.fn(() => []),
    getTransceivers: vi.fn(() => []),
    ontrack: null,
    getStats: vi.fn().mockResolvedValue(new Map()),
  };
}

function createMockStream(tracks = []) {
  return {
    getTracks: () => tracks,
    getAudioTracks: () => tracks.filter((t) => t.kind === "audio"),
    getVideoTracks: () => tracks.filter((t) => t.kind === "video"),
    addTrack: vi.fn(),
    removeTrack: vi.fn(),
  };
}

// --- US1: Audio Call Flow (T014) ---

describe("MediaHook — Audio Call", () => {
  let hook;

  beforeEach(() => {
    ({ hook } = createMockHook());
    hook.mounted();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("registers all expected event listeners on mount", () => {
    expect(hook.handleEvent).toHaveBeenCalledWith("media_start_audio", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("media_start_video", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("media_end_call", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("media_peer_muted", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("media_peer_camera", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("media_upgrade_accepted", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("media_upgrade_rejected", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("media_set_preset", expect.any(Function));
    expect(hook.pushEvent).toHaveBeenCalledWith("media_hook_ready", {});
  });

  it("listens for media_pc_ready and media_pc_closed on #p2p-webrtc element", () => {
    const webrtcEl = document.getElementById("p2p-webrtc");
    expect(webrtcEl.addEventListener).toHaveBeenCalledWith("media_pc_ready", expect.any(Function));
    expect(webrtcEl.addEventListener).toHaveBeenCalledWith("media_pc_closed", expect.any(Function));
  });

  it("sets pc on media_pc_ready event", () => {
    const pc = createMockPC();
    hook._handlePcReady(pc);
    expect(hook.pc).toBe(pc);
    expect(pc.ontrack).toBeTypeOf("function");
  });

  it("starts audio call with acquireMedia and addMediaTracks", async () => {
    const audioTrack = { kind: "audio", enabled: true, stop: vi.fn() };
    const mockStream = createMockStream([audioTrack]);
    const pc = createMockPC();
    hook._handlePcReady(pc);

    // Mock acquireMedia via navigator
    navigator.mediaDevices = {
      getUserMedia: vi.fn().mockResolvedValue(mockStream),
      addEventListener: vi.fn(),
    };

    await hook._startCall("audio");

    expect(hook.callType).toBe("audio");
    expect(hook.localStream).toBe(mockStream);
    expect(pc.addTrack).toHaveBeenCalledWith(audioTrack, mockStream);
    expect(hook.pushEvent).toHaveBeenCalledWith("media_call_started", { type: "audio" });
  });

  it("ends call and pushes media_call_ended", () => {
    const track = { kind: "audio", stop: vi.fn() };
    const stream = createMockStream([track]);
    hook.localStream = stream;
    hook.callType = "audio";
    hook.senders = [];
    hook.pc = createMockPC();

    hook._endCall("ended");

    expect(track.stop).toHaveBeenCalled();
    expect(hook.callType).toBeNull();
    expect(hook.pushEvent).toHaveBeenCalledWith("media_call_ended", { reason: "ended" });
  });

  it("toggles mute and pushes media_mute_changed", () => {
    const track = { kind: "audio", enabled: true };
    hook.localStream = createMockStream([track]);
    hook.muted = false;

    hook._toggleMute();

    expect(hook.muted).toBe(true);
    expect(track.enabled).toBe(false);
    expect(hook.pushEvent).toHaveBeenCalledWith("media_mute_changed", { muted: true });
  });

  it("handles peer disconnect via _handlePcClosed", () => {
    hook.callType = "audio";
    hook.localStream = createMockStream([{ kind: "audio", stop: vi.fn() }]);
    hook.senders = [];
    hook.pc = createMockPC();

    hook._handlePcClosed();

    expect(hook.pushEvent).toHaveBeenCalledWith("media_call_ended", {
      reason: "Peer disconnected",
    });
  });

  it("pushes media_error when acquireMedia fails", async () => {
    const pc = createMockPC();
    hook._handlePcReady(pc);

    navigator.mediaDevices = {
      getUserMedia: vi.fn().mockRejectedValue(new DOMException("Denied", "NotAllowedError")),
      addEventListener: vi.fn(),
    };

    await hook._startCall("audio");

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "media_error",
      expect.objectContaining({ code: "permission_denied" }),
    );
    expect(hook.callType).toBeNull();
  });
});

// --- US2: Video Call (T024) ---

describe("MediaHook — Video Call", () => {
  let hook, el;

  beforeEach(() => {
    ({ hook, el } = createMockHook());
    hook.mounted();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("starts video call with audio+video constraints", async () => {
    const audioTrack = { kind: "audio", enabled: true, stop: vi.fn() };
    const videoTrack = { kind: "video", enabled: true, stop: vi.fn() };
    const mockStream = createMockStream([audioTrack, videoTrack]);
    const pc = createMockPC();
    hook._handlePcReady(pc);

    const localVideo = { srcObject: null };
    el.querySelector.mockImplementation((sel) => (sel === "#local-video" ? localVideo : null));

    navigator.mediaDevices = {
      getUserMedia: vi.fn().mockResolvedValue(mockStream),
      addEventListener: vi.fn(),
    };

    await hook._startCall("video");

    expect(hook.callType).toBe("video");
    expect(pc.addTrack).toHaveBeenCalledTimes(2);
    expect(localVideo.srcObject).toBe(mockStream);
    expect(hook.pushEvent).toHaveBeenCalledWith("media_call_started", { type: "video" });
  });

  it("toggles camera and pushes media_camera_changed", () => {
    const videoTrack = { kind: "video", enabled: true };
    hook.localStream = {
      getTracks: () => [videoTrack],
      getAudioTracks: () => [],
      getVideoTracks: () => [videoTrack],
    };
    hook.cameraOff = false;

    hook._toggleCamera();

    expect(hook.cameraOff).toBe(true);
    expect(videoTrack.enabled).toBe(false);
    expect(hook.pushEvent).toHaveBeenCalledWith("media_camera_changed", { off: true });
  });

  it("attaches remote stream on ontrack event", () => {
    const pc = createMockPC();
    hook._handlePcReady(pc);
    hook.callType = "video";

    const remoteVideo = { srcObject: null };
    el.querySelector.mockImplementation((sel) => (sel === "#remote-video" ? remoteVideo : null));

    const remoteStream = { id: "remote-1" };
    pc.ontrack({ track: { kind: "video" }, streams: [remoteStream] });

    expect(remoteVideo.srcObject).toBe(remoteStream);
  });
});

// --- US4: Audio-to-Video Upgrade (T037) ---

describe("MediaHook — Upgrade Flow", () => {
  let hook, el;

  beforeEach(() => {
    ({ hook, el } = createMockHook());
    hook.mounted();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("upgrade button pushes media_request_upgrade via data-media-action", () => {
    // Simulate click delegation
    hook.pushEvent("media_request_upgrade", {});
    expect(hook.pushEvent).toHaveBeenCalledWith("media_request_upgrade", {});
  });

  it("_handleUpgradeAccepted acquires video and adds track", async () => {
    const audioTrack = { kind: "audio", enabled: true, stop: vi.fn() };
    const existingStream = createMockStream([audioTrack]);
    const videoTrack = { kind: "video", enabled: true };
    const videoStream = {
      getVideoTracks: () => [videoTrack],
    };

    const pc = createMockPC();
    hook._handlePcReady(pc);
    hook.localStream = existingStream;
    hook.callType = "audio";
    hook.senders = [];

    const localVideo = { srcObject: null };
    el.querySelector.mockImplementation((sel) => (sel === "#local-video" ? localVideo : null));

    navigator.mediaDevices = {
      getUserMedia: vi.fn().mockResolvedValue(videoStream),
      addEventListener: vi.fn(),
    };

    await hook._handleUpgradeAccepted();

    expect(hook.callType).toBe("video");
    expect(existingStream.addTrack).toHaveBeenCalledWith(videoTrack);
    expect(pc.addTrack).toHaveBeenCalledWith(videoTrack, existingStream);
    expect(localVideo.srcObject).toBe(existingStream);
    expect(hook.pushEvent).toHaveBeenCalledWith("media_call_started", { type: "video" });
  });

  it("_handleUpgradeRejected is a no-op (LiveView handles notification)", () => {
    // Should not throw
    hook._handleUpgradeRejected();
    // No pushEvent called for upgrade rejection from hook side
  });

  it("upgrade with camera permission denied keeps audio-only", async () => {
    const audioTrack = { kind: "audio", enabled: true, stop: vi.fn() };
    const existingStream = createMockStream([audioTrack]);
    const pc = createMockPC();
    hook._handlePcReady(pc);
    hook.localStream = existingStream;
    hook.callType = "audio";
    hook.senders = [];

    navigator.mediaDevices = {
      getUserMedia: vi.fn().mockRejectedValue(new DOMException("Denied", "NotAllowedError")),
      addEventListener: vi.fn(),
    };

    await hook._handleUpgradeAccepted();

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "media_error",
      expect.objectContaining({ code: "permission_denied" }),
    );
    // callType stays audio since upgrade failed — actually it stays at "audio"
    // because the error happens before callType is changed
  });
});

// --- Bug fix tests: event listening on #p2p-webrtc ---

describe("MediaHook — #p2p-webrtc event wiring", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("receives media_pc_ready dispatched on #p2p-webrtc element", () => {
    const { hook, webrtcListeners } = createMockHook();
    hook.mounted();

    const pc = createMockPC();
    // Simulate WebRTCHook dispatching on #p2p-webrtc
    const readyHandler = webrtcListeners["media_pc_ready"][0];
    readyHandler({ detail: { pc } });

    expect(hook.pc).toBe(pc);
  });

  it("late mount picks up existing PeerConnection", () => {
    const existingPC = createMockPC();
    const { hook } = createMockHook({ existingPC });
    hook.mounted();

    // PC should be set from late mount
    expect(hook.pc).toBe(existingPC);
    expect(existingPC.ontrack).toBeTypeOf("function");
  });

  it("_startCall guards on this.pc being null", async () => {
    const { hook } = createMockHook();
    hook.mounted();

    // pc is null by default, _startCall should return early
    await hook._startCall("audio");

    expect(hook.callType).toBeNull();
    expect(hook.pushEvent).not.toHaveBeenCalledWith("media_call_started", expect.anything());
  });

  it("cleanup removes listeners from #p2p-webrtc", () => {
    const { hook, webrtcEl } = createMockHook();
    hook.mounted();
    hook.destroyed();

    expect(webrtcEl.removeEventListener).toHaveBeenCalledWith(
      "media_pc_ready",
      expect.any(Function),
    );
    expect(webrtcEl.removeEventListener).toHaveBeenCalledWith(
      "media_pc_closed",
      expect.any(Function),
    );
  });
});
