import { describe, it, expect, vi, afterEach } from "vitest";
import LobbyMediaHook from "../../../js/hooks/lobby/lobby_media_hook.js";

// Exercises the lobby-only behaviours layered on the shared RTC media factory:
// recvonly auto-join and the stalled-media watchdog.

function setup({ querySelector = () => null, closest = () => null } = {}) {
  const pushed = [];
  const handlers = {};
  const webrtcEl = {
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
    _peerConnection: null,
  };

  vi.spyOn(document, "getElementById").mockImplementation((id) =>
    id === "lobby-webrtc" ? webrtcEl : null,
  );

  const el = {
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    querySelector: vi.fn(querySelector),
    closest: vi.fn(closest),
    dispatchEvent: vi.fn(),
  };

  const hook = Object.create(LobbyMediaHook);
  hook.el = el;
  hook.pushEvent = vi.fn((event, payload) => pushed.push({ event, payload }));
  hook.handleEvent = vi.fn((event, handler) => {
    handlers[event] = handler;
  });
  hook.mounted();

  return { hook, pushed, handlers, webrtcEl };
}

function shortcut(key, target = document.body) {
  const event = new KeyboardEvent("keydown", {
    key,
    ctrlKey: true,
    shiftKey: true,
    bubbles: true,
    cancelable: true,
  });

  target.dispatchEvent(event);
  return event;
}

describe("LobbyMediaHook auto-join", () => {
  let hook;

  afterEach(() => {
    if (hook) hook.destroyed();
    hook = null;
    vi.restoreAllMocks();
  });

  it("enters the call recvonly without acquiring media or reporting send state", () => {
    const ctx = setup();
    hook = ctx.hook;

    ctx.handlers["lobby_media_join"]();

    expect(hook.inCall).toBe(true);
    expect(hook.audioOn).toBe(false);
    expect(hook.videoOn).toBe(false);
    expect(hook.localStream).toBe(null);
    // The server already placed us in the call — the hook must not echo a start.
    expect(ctx.pushed.some((e) => e.event === "lobby_media_call_started")).toBe(false);
  });

  it("auto-join falls back to recvonly when its own media cannot open", async () => {
    const ctx = setup();
    hook = ctx.hook;
    hook.pc = {}; // PeerConnection is ready.

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getUserMedia: vi
          .fn()
          .mockRejectedValue(Object.assign(new Error("denied"), { name: "NotAllowedError" })),
      },
    });

    // The server asks us to open media by default (auto), but permission is denied.
    await hook._startCall("audio", { auto: true });

    // We still join the call as a pure receiver so the user can watch and listen.
    expect(hook.inCall).toBe(true);
    expect(hook.callType).toBe("receiving");
    expect(hook.localStream).toBe(null);
    // Soft device fallback, not the hard media error a first mover would get.
    expect(ctx.pushed.some((e) => e.event === "lobby_media_error")).toBe(false);
    expect(ctx.pushed.some((e) => e.event === "lobby_media_device_fallback")).toBe(true);
  });

  it("starts media with selected setup devices", async () => {
    const ctx = setup();
    hook = ctx.hook;

    const audioTrack = { kind: "audio", enabled: true, stop: vi.fn() };
    const videoTrack = { kind: "video", enabled: true, stop: vi.fn() };
    const stream = {
      getTracks: vi.fn(() => [audioTrack, videoTrack]),
      getAudioTracks: vi.fn(() => [audioTrack]),
      getVideoTracks: vi.fn(() => [videoTrack]),
    };

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getUserMedia: vi.fn().mockResolvedValue(stream),
        enumerateDevices: vi.fn(async () => []),
      },
    });

    hook.pc = {
      addTrack: vi.fn((track) => ({ track })),
      getTransceivers: vi.fn(() => []),
    };

    await hook._startCall("video", {
      device_preferences: {
        audio_input_id: "mic-1",
        video_input_id: "cam-1",
      },
    });

    expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalledWith({
      audio: expect.objectContaining({ deviceId: { exact: "mic-1" } }),
      video: expect.objectContaining({ deviceId: { exact: "cam-1" } }),
    });
    expect(hook.audioOn).toBe(true);
    expect(hook.videoOn).toBe(true);
  });

  it("asks the WebRTC hook to recover a remote video track stuck muted", () => {
    vi.useFakeTimers();
    const ctx = setup();
    hook = ctx.hook;

    ctx.handlers["lobby_media_join"]();
    // A remote video track that negotiated but is not flowing stays muted.
    hook.remoteStream = {
      getVideoTracks: () => [{ readyState: "live", muted: true }],
    };

    vi.advanceTimersByTime(6000);

    const recover = ctx.webrtcEl.dispatchEvent.mock.calls.find(
      ([event]) => event.type === "lobby_media_recover",
    );
    expect(recover).toBeTruthy();

    vi.useRealTimers();
  });

  it("does not trigger recovery while remote video is flowing", () => {
    vi.useFakeTimers();
    const ctx = setup();
    hook = ctx.hook;

    ctx.handlers["lobby_media_join"]();
    hook.remoteStream = {
      getVideoTracks: () => [{ readyState: "live", muted: false }],
    };

    vi.advanceTimersByTime(6000);

    const recover = ctx.webrtcEl.dispatchEvent.mock.calls.find(
      ([event]) => event.type === "lobby_media_recover",
    );
    expect(recover).toBeFalsy();

    vi.useRealTimers();
  });

  it("starts and stops screen sharing by replacing the published video track", async () => {
    const localVideo = {};
    const ctx = setup({
      querySelector: (selector) => (selector === "#lobby-local-video" ? localVideo : null),
    });
    hook = ctx.hook;

    const cameraTrack = { id: "camera-track", kind: "video", readyState: "live", stop: vi.fn() };
    const screenTrack = {
      id: "screen-track",
      kind: "video",
      contentHint: "",
      readyState: "live",
      stop: vi.fn(),
    };
    const screenStream = {
      id: "screen-stream",
      getVideoTracks: vi.fn(() => [screenTrack]),
      getTracks: vi.fn(() => [screenTrack]),
    };
    const localStream = {
      getVideoTracks: vi.fn(() => [cameraTrack]),
      getAudioTracks: vi.fn(() => []),
      getTracks: vi.fn(() => [cameraTrack]),
      addTrack: vi.fn(),
      removeTrack: vi.fn(),
    };
    const sender = {
      track: cameraTrack,
      replaceTrack: vi.fn(async (track) => {
        sender.track = track;
      }),
      getParameters: vi.fn(() => ({ encodings: [{}] })),
      setParameters: vi.fn(),
    };

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getDisplayMedia: vi.fn().mockResolvedValue(screenStream),
      },
    });

    hook.pc = { addTrack: vi.fn(), removeTrack: vi.fn() };
    hook.localStream = localStream;
    hook.senders = [sender];
    hook.inCall = true;
    hook.audioOn = true;
    hook.videoOn = true;

    await hook._toggleScreenShare();

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
    expect(localStream.removeTrack).toHaveBeenCalledWith(cameraTrack);
    expect(localStream.addTrack).toHaveBeenCalledWith(screenTrack);
    expect(localVideo.srcObject).toBe(localStream);
    expect(hook.screenShare.active).toBe(true);
    expect(ctx.pushed).toContainEqual({
      event: "lobby_media_screen_share_changed",
      payload: { active: true },
    });
    expect(ctx.webrtcEl.dispatchEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "lobby_media_source_changed",
        detail: { source: "screen" },
      }),
    );

    await hook._toggleScreenShare();

    expect(sender.replaceTrack).toHaveBeenCalledWith(cameraTrack);
    expect(sender.setParameters.mock.calls.at(-1)[0].encodings[0]).toEqual(
      expect.objectContaining({ maxBitrate: 400_000, maxFramerate: 15 }),
    );
    expect(localStream.removeTrack).toHaveBeenCalledWith(screenTrack);
    expect(localStream.addTrack).toHaveBeenCalledWith(cameraTrack);
    expect(screenTrack.stop).toHaveBeenCalled();
    expect(hook.screenShare.active).toBe(false);
    expect(ctx.pushed).toContainEqual({
      event: "lobby_media_screen_share_changed",
      payload: { active: false },
    });
    expect(ctx.webrtcEl.dispatchEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: "lobby_media_source_changed",
        detail: { source: "camera" },
      }),
    );
  });

  it("uses focused-window shortcuts to toggle real audio tracks", () => {
    const audioTrack = { kind: "audio", enabled: true, stop: vi.fn() };
    const ctx = setup();
    hook = ctx.hook;

    hook.inCall = true;
    hook.audioOn = true;
    hook.localStream = {
      getAudioTracks: vi.fn(() => [audioTrack]),
      getVideoTracks: vi.fn(() => []),
      getTracks: vi.fn(() => [audioTrack]),
    };

    const event = shortcut("ArrowUp");

    expect(event.defaultPrevented).toBe(true);
    expect(audioTrack.enabled).toBe(false);
    expect(hook.muted).toBe(true);
    expect(ctx.pushed).toContainEqual({
      event: "lobby_media_mute_changed",
      payload: { muted: true },
    });
  });

  it("uses focused-window shortcuts to request layout and self-view changes", () => {
    const ctx = setup();
    hook = ctx.hook;

    shortcut("ArrowRight");
    shortcut("ArrowDown");

    expect(ctx.pushed).toContainEqual({
      event: "cycle_call_layout",
      payload: { source: "shortcut" },
    });
    expect(ctx.pushed).toContainEqual({
      event: "cycle_call_self_view",
      payload: { source: "shortcut" },
    });
  });

  it("does not fire P2P media shortcuts from editable fields", () => {
    const audioTrack = { kind: "audio", enabled: true, stop: vi.fn() };
    const input = document.createElement("input");
    document.body.appendChild(input);
    const ctx = setup();
    hook = ctx.hook;

    hook.inCall = true;
    hook.audioOn = true;
    hook.localStream = {
      getAudioTracks: vi.fn(() => [audioTrack]),
      getVideoTracks: vi.fn(() => []),
      getTracks: vi.fn(() => [audioTrack]),
    };

    const event = shortcut("ArrowUp", input);

    expect(event.defaultPrevented).toBe(false);
    expect(audioTrack.enabled).toBe(true);
    expect(ctx.pushed.some((item) => item.event === "lobby_media_mute_changed")).toBe(false);
    input.remove();
  });

  it("does not fire P2P media shortcuts when the call window is blurred", () => {
    const windowEl = {
      getAttribute: vi.fn(() => "p2p-call"),
      classList: { contains: vi.fn((className) => className === "desktop-window--blurred") },
    };
    const ctx = setup({ closest: () => windowEl });
    hook = ctx.hook;

    shortcut("ArrowRight");

    expect(ctx.pushed.some((item) => item.event === "cycle_call_layout")).toBe(false);
  });
});
