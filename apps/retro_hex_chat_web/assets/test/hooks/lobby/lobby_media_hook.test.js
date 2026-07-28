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

  it("falls back to the default camera when the active camera disappears", async () => {
    const ctx = setup();
    hook = ctx.hook;
    let deviceChangeHandler = null;
    let tracks;

    const audioTrack = {
      kind: "audio",
      enabled: true,
      stop: vi.fn(),
      getSettings: vi.fn(() => ({ deviceId: "mic-1" })),
    };
    const oldVideoTrack = {
      kind: "video",
      enabled: true,
      stop: vi.fn(),
      getSettings: vi.fn(() => ({ deviceId: "cam-old" })),
    };
    const newVideoTrack = {
      kind: "video",
      enabled: true,
      stop: vi.fn(),
      getSettings: vi.fn(() => ({ deviceId: "cam-new" })),
    };

    tracks = [audioTrack, oldVideoTrack];
    const stream = {
      getTracks: vi.fn(() => tracks),
      getAudioTracks: vi.fn(() => tracks.filter((track) => track.kind === "audio")),
      getVideoTracks: vi.fn(() => tracks.filter((track) => track.kind === "video")),
      removeTrack: vi.fn((track) => {
        tracks = tracks.filter((candidate) => candidate !== track);
      }),
      addTrack: vi.fn((track) => {
        tracks.push(track);
      }),
    };
    const newVideoStream = {
      getTracks: vi.fn(() => [newVideoTrack]),
      getAudioTracks: vi.fn(() => []),
      getVideoTracks: vi.fn(() => [newVideoTrack]),
    };
    const audioSender = { track: audioTrack };
    const videoSender = {
      track: oldVideoTrack,
      replaceTrack: vi.fn(async (track) => {
        videoSender.track = track;
      }),
      getParameters: vi.fn(() => ({ encodings: [{}] })),
      setParameters: vi.fn(async () => {}),
    };

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        getUserMedia: vi.fn().mockResolvedValueOnce(stream).mockResolvedValueOnce(newVideoStream),
        enumerateDevices: vi.fn(async () => [
          { kind: "audioinput", deviceId: "mic-1", label: "Mic" },
          { kind: "videoinput", deviceId: "cam-new", label: "Camera" },
        ]),
        addEventListener: vi.fn((event, handler) => {
          if (event === "devicechange") deviceChangeHandler = handler;
        }),
        removeEventListener: vi.fn(),
      },
    });

    hook.pc = {
      addTrack: vi.fn((track) => (track.kind === "audio" ? audioSender : videoSender)),
      getTransceivers: vi.fn(() => []),
    };

    await hook._startCall("video");
    await deviceChangeHandler();

    expect(videoSender.replaceTrack).toHaveBeenCalledWith(newVideoTrack);
    expect(oldVideoTrack.stop).toHaveBeenCalled();
    expect(hook.localStream.getVideoTracks()).toEqual([newVideoTrack]);
    expect(ctx.pushed).toContainEqual({
      event: "lobby_media_device_fallback",
      payload: { message: "Device disconnected, using default device" },
    });
  });

  it("queues auto-start media until the peer connection is ready", async () => {
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

    await hook._startCall("video", { auto: true });
    expect(navigator.mediaDevices.getUserMedia).not.toHaveBeenCalled();

    const pc = {
      addTrack: vi.fn((track) => ({ track })),
      getTransceivers: vi.fn(() => []),
    };

    hook._handlePcReady(pc);

    await vi.waitFor(() => {
      expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalled();
      expect(pc.addTrack).toHaveBeenCalledWith(audioTrack, stream);
      expect(pc.addTrack).toHaveBeenCalledWith(videoTrack, stream);
      expect(hook.inCall).toBe(true);
      expect(hook.videoOn).toBe(true);
    });
  });

  it("republishes local media and drops stale remote tracks when the peer connection is replaced", async () => {
    const ctx = setup();
    hook = ctx.hook;

    const audioTrack = { id: "audio-local", kind: "audio", readyState: "live", stop: vi.fn() };
    const videoTrack = { id: "video-local", kind: "video", readyState: "live", stop: vi.fn() };
    const oldRemoteTrack = {
      id: "video-old-remote",
      kind: "video",
      readyState: "live",
      muted: true,
    };
    const localStream = {
      getTracks: vi.fn(() => [audioTrack, videoTrack]),
      getAudioTracks: vi.fn(() => [audioTrack]),
      getVideoTracks: vi.fn(() => [videoTrack]),
    };
    const oldRemoteStream = {
      getTracks: vi.fn(() => [oldRemoteTrack]),
      getVideoTracks: vi.fn(() => [oldRemoteTrack]),
      getAudioTracks: vi.fn(() => []),
    };
    const oldPc = { id: "old-pc" };
    const newPc = {
      addTrack: vi.fn((track) => ({ track })),
      getReceivers: vi.fn(() => []),
      getTransceivers: vi.fn(() => []),
    };

    hook.pc = oldPc;
    hook._sendersPc = oldPc;
    hook.localStream = localStream;
    hook.remoteStream = oldRemoteStream;
    hook.remoteHasVideo = true;
    hook.senders = [{ track: audioTrack }, { track: videoTrack }];
    hook.inCall = true;
    hook.audioOn = true;
    hook.videoOn = true;
    hook.callType = "video";

    hook._handlePcReady(newPc);

    await vi.waitFor(() => {
      expect(newPc.addTrack).toHaveBeenCalledWith(audioTrack, localStream);
      expect(newPc.addTrack).toHaveBeenCalledWith(videoTrack, localStream);
      expect(hook._sendersPc).toBe(newPc);
    });

    expect(hook.senders.map((sender) => sender.track)).toEqual([audioTrack, videoTrack]);
    expect(hook.remoteStream).toBeNull();
    expect(hook.remoteHasVideo).toBe(false);
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

  it("asks the WebRTC hook to recover when expected remote video never arrives", () => {
    vi.useFakeTimers();
    const ctx = setup();
    hook = ctx.hook;
    hook.pc = { getReceivers: vi.fn(() => []), getStats: vi.fn(async () => new Map()) };

    ctx.handlers["lobby_media_peer_media"]({ audio: true, video: true });
    ctx.handlers["lobby_media_join"]({ expected_video: true });

    vi.advanceTimersByTime(6000);

    const recover = ctx.webrtcEl.dispatchEvent.mock.calls
      .map(([event]) => event)
      .find((event) => event.type === "lobby_media_recover");

    expect(recover).toBeTruthy();
    expect(recover.detail).toEqual(
      expect.objectContaining({
        restart: false,
        reason: "remote_video_missing",
      }),
    );

    vi.useRealTimers();
  });

  it("escalates missing remote video recovery to a coordinated restart", () => {
    vi.useFakeTimers();
    const ctx = setup();
    hook = ctx.hook;
    hook.pc = { getReceivers: vi.fn(() => []), getStats: vi.fn(async () => new Map()) };

    ctx.handlers["lobby_media_peer_media"]({ audio: true, video: true });
    ctx.handlers["lobby_media_join"]({ expected_video: true });

    vi.advanceTimersByTime(6000);
    vi.advanceTimersByTime(5000);

    const recoveries = ctx.webrtcEl.dispatchEvent.mock.calls
      .map(([event]) => event)
      .filter((event) => event.type === "lobby_media_recover");

    expect(recoveries.length).toBeGreaterThanOrEqual(2);
    expect(recoveries.at(-1).detail).toEqual(
      expect.objectContaining({
        restart: true,
        reason: "remote_video_missing_restart",
      }),
    );

    vi.useRealTimers();
  });

  it("does not recover missing remote video when the peer camera is off", () => {
    vi.useFakeTimers();
    const ctx = setup();
    hook = ctx.hook;
    hook.pc = { getReceivers: vi.fn(() => []), getStats: vi.fn(async () => new Map()) };

    ctx.handlers["lobby_media_peer_media"]({ audio: true, video: true });
    ctx.handlers["lobby_media_peer_camera"]({ off: true });
    ctx.handlers["lobby_media_join"]({ expected_video: true });

    vi.advanceTimersByTime(8000);

    const recoveries = ctx.webrtcEl.dispatchEvent.mock.calls.filter(
      ([event]) => event.type === "lobby_media_recover",
    );
    expect(recoveries).toHaveLength(0);

    vi.useRealTimers();
  });

  it("escalates repeated stalled remote video recovery to a coordinated restart", () => {
    vi.useFakeTimers();
    const ctx = setup();
    hook = ctx.hook;

    ctx.handlers["lobby_media_join"]();
    hook.remoteStream = {
      getVideoTracks: () => [{ readyState: "live", muted: true }],
    };

    vi.advanceTimersByTime(6000);
    vi.advanceTimersByTime(5000);

    const recoveries = ctx.webrtcEl.dispatchEvent.mock.calls
      .map(([event]) => event)
      .filter((event) => event.type === "lobby_media_recover");

    expect(recoveries.length).toBeGreaterThanOrEqual(2);
    expect(recoveries[0].detail).toEqual(
      expect.objectContaining({
        restart: false,
        reason: "remote_video_stalled",
      }),
    );
    expect(recoveries.at(-1).detail).toEqual(
      expect.objectContaining({
        restart: true,
        reason: "remote_video_stalled_restart",
      }),
    );

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

  it("mutes the remote video element and starts playback when attaching a stream", async () => {
    const remoteVideo = document.createElement("video");
    const remoteAudio = document.createElement("audio");
    const videoTrack = { id: "video-1", kind: "video", readyState: "live", stop: vi.fn() };
    const audioTrack = { id: "audio-1", kind: "audio", readyState: "live", stop: vi.fn() };
    const remoteStream = {
      getVideoTracks: vi.fn(() => [videoTrack]),
      getAudioTracks: vi.fn(() => [audioTrack]),
      getTracks: vi.fn(() => [videoTrack, audioTrack]),
    };
    const playVideo = vi.spyOn(remoteVideo, "play").mockResolvedValue(undefined);
    const playAudio = vi.spyOn(remoteAudio, "play").mockResolvedValue(undefined);
    const ctx = setup({
      querySelector: (selector) => {
        if (selector === "#lobby-remote-video") return remoteVideo;
        if (selector === "#lobby-remote-audio") return remoteAudio;
        return null;
      },
    });
    hook = ctx.hook;
    hook.remoteStream = remoteStream;
    hook.remoteHasVideo = true;

    hook._attachMediaElements();
    await Promise.resolve();

    expect(remoteVideo.srcObject).toBe(remoteStream);
    expect(remoteVideo.muted).toBe(true);
    expect(remoteVideo.autoplay).toBe(true);
    expect(remoteVideo.playsInline).toBe(true);
    expect(playVideo).toHaveBeenCalled();
    expect(remoteAudio.srcObject).toBe(remoteStream);
    expect(remoteAudio.muted).toBe(false);
    expect(remoteAudio.autoplay).toBe(true);
    expect(playAudio).toHaveBeenCalled();
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
