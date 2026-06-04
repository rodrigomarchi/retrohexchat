import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import GameMediaHook from "../../../js/hooks/games/game_media_hook.js";

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
  };

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
    if (id === "game-webrtc") return webrtcEl;
    return origGetById(id);
  });

  const hook = Object.create(GameMediaHook);
  hook.el = el;
  hook.pushEvent = vi.fn((event, payload) => pushedEvents.push({ event, payload }));
  hook.handleEvent = vi.fn((event, handler) => {
    eventHandlers[event] = handler;
  });

  return { hook, el, eventHandlers, pushedEvents, webrtcEl, webrtcListeners };
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

describe("GameMediaHook", () => {
  let hook;

  beforeEach(() => {
    ({ hook } = createMockHook());
    hook.mounted();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("registers game-prefixed server events and announces readiness", () => {
    expect(hook.handleEvent).toHaveBeenCalledWith("game_media_start_audio", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("game_media_start_video", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("game_media_end_call", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("game_media_peer_muted", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("game_media_peer_camera", expect.any(Function));
    expect(hook.pushEvent).toHaveBeenCalledWith("game_media_hook_ready", {});
  });

  it("listens for the game PeerConnection on #game-webrtc", () => {
    const webrtcEl = document.getElementById("game-webrtc");
    expect(webrtcEl.addEventListener).toHaveBeenCalledWith(
      "game_media_pc_ready",
      expect.any(Function),
    );
    expect(webrtcEl.addEventListener).toHaveBeenCalledWith(
      "game_media_pc_closed",
      expect.any(Function),
    );
  });

  it("late mount picks up an existing game PeerConnection", () => {
    vi.restoreAllMocks();
    const existingPC = createMockPC();
    const { hook: lateHook } = createMockHook({ existingPC });

    lateHook.mounted();

    expect(lateHook.pc).toBe(existingPC);
    expect(existingPC.ontrack).toBeTypeOf("function");
  });

  it("starts a video call using game media element ids and events", async () => {
    const audioTrack = { kind: "audio", enabled: true, stop: vi.fn() };
    const videoTrack = { kind: "video", enabled: true, stop: vi.fn() };
    const mockStream = createMockStream([audioTrack, videoTrack]);
    const pc = createMockPC();
    const localVideo = { srcObject: null };

    hook.el.querySelector.mockImplementation((selector) =>
      selector === "#game-local-video" ? localVideo : null,
    );
    hook._handlePcReady(pc);

    navigator.mediaDevices = {
      getUserMedia: vi.fn().mockResolvedValue(mockStream),
      addEventListener: vi.fn(),
    };

    await hook._startCall("video");

    expect(pc.addTrack).toHaveBeenCalledTimes(2);
    expect(localVideo.srcObject).toBe(mockStream);
    expect(hook.pushEvent).toHaveBeenCalledWith("game_media_call_started", { type: "video" });
  });

  it("attaches remote tracks after LiveView renders video elements", () => {
    const pc = createMockPC();
    hook._handlePcReady(pc);

    const remoteStream = { id: "remote-stream" };
    pc.ontrack({ track: { kind: "video" }, streams: [remoteStream] });

    const remoteVideo = { srcObject: null };
    hook.el.querySelector.mockImplementation((selector) =>
      selector === "#game-remote-video" ? remoteVideo : null,
    );

    hook.updated();

    expect(remoteVideo.srcObject).toBe(remoteStream);
  });
});
