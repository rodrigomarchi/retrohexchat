import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { createRtcMediaHook } from "../../../js/lib/p2p/rtc_media_hook_factory.js";
import { FakeRTCPeerConnection } from "../../helpers/rtc_peer_connection.js";
import { mountHook, simulateEvent, getPushEvents } from "../../helpers/hook_helper.js";

// Black-box test for the RTC media hook FACTORY. The factory's logic was only
// proven through the produced hook's private methods (in the lobby hook test);
// here it is driven purely through the observable surface: mounted(), the
// registered server-event handlers, the peer connection's own ontrack/pc-ready
// events, DOM control clicks, and updated() — asserting on pushEvent output,
// FakeRTCPeerConnection state and the events dispatched at the WebRTC element.

// A minimal config, structurally identical to the one the lobby hook passes.
const CONFIG = {
  webrtcElementId: "test-webrtc",
  pcReadyEvent: "test_pc_ready",
  pcClosedEvent: "test_pc_closed",
  actionAttribute: "data-media-action",
  elementIds: {
    remoteVideo: "remote-video",
    localVideo: "local-video",
    remoteAudio: "remote-audio",
  },
  serverEvents: {
    startAudio: "start_audio",
    startVideo: "start_video",
    endCall: "end_call",
    peerMedia: "peer_media",
    peerMuted: "peer_muted",
    peerCamera: "peer_camera",
    setPreset: "set_preset",
    joinCall: "join_call",
  },
  clientEvents: {
    ready: "media_ready",
    error: "media_error",
    callStarted: "call_started",
    callEnded: "call_ended",
    muteChanged: "mute_changed",
    cameraChanged: "camera_changed",
    qualityUpdate: "quality_update",
    durationTick: "duration_tick",
    devicesListed: "devices_listed",
    deviceFallback: "device_fallback",
    screenShareChanged: "screen_share_changed",
  },
};

const HOOK_HTML = `
  <video id="local-video"></video>
  <video id="remote-video"></video>
  <audio id="remote-audio"></audio>
  <button data-media-action="screen-share">share</button>
  <button data-media-action="end-call">end</button>
`;

let streamSeq = 0;

function makeTrack(kind, id = `${kind}-${++streamSeq}`) {
  return {
    kind,
    id,
    readyState: "live",
    enabled: true,
    muted: false,
    contentHint: "",
    stop: vi.fn(function stop() {
      this.readyState = "ended";
    }),
    getSettings: vi.fn(() => ({ deviceId: `${kind}-device` })),
  };
}

function makeStream(kinds) {
  let tracks = kinds.map((kind) => makeTrack(kind));
  return {
    id: `stream-${++streamSeq}`,
    getTracks: () => tracks,
    getAudioTracks: () => tracks.filter((track) => track.kind === "audio"),
    getVideoTracks: () => tracks.filter((track) => track.kind === "video"),
    addTrack: (track) => {
      if (!tracks.includes(track)) tracks.push(track);
    },
    removeTrack: (track) => {
      tracks = tracks.filter((candidate) => candidate !== track);
    },
  };
}

// jsdom has no MediaStream; the remote stream's identity is what decides whether
// attaching reloads the element, so it must be modelled.
class FakeMediaStream {
  constructor(tracks = []) {
    this.id = `remote-stream-${++streamSeq}`;
    this._tracks = [...tracks];
  }
  getTracks() {
    return this._tracks;
  }
  getVideoTracks() {
    return this._tracks.filter((track) => track.kind === "video");
  }
  getAudioTracks() {
    return this._tracks.filter((track) => track.kind === "audio");
  }
  addTrack(track) {
    if (!this._tracks.includes(track)) this._tracks.push(track);
  }
}

function stubMediaDevices(overrides = {}) {
  Object.defineProperty(navigator, "mediaDevices", {
    configurable: true,
    value: {
      getUserMedia: vi.fn(async (constraints = {}) => {
        const kinds = [];
        if (constraints.audio) kinds.push("audio");
        if (constraints.video) kinds.push("video");
        return makeStream(kinds);
      }),
      getDisplayMedia: vi.fn(async () => makeStream(["video"])),
      enumerateDevices: vi.fn(async () => []),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      ...overrides,
    },
  });
}

function setup() {
  const webrtcEl = document.createElement("div");
  webrtcEl.id = CONFIG.webrtcElementId;
  document.body.appendChild(webrtcEl);

  const recoverEvents = [];
  const sourceEvents = [];
  webrtcEl.addEventListener("lobby_media_recover", (event) => recoverEvents.push(event));
  webrtcEl.addEventListener("lobby_media_source_changed", (event) => sourceEvents.push(event));

  const hookDef = createRtcMediaHook(CONFIG);
  const hook = mountHook(hookDef, { html: HOOK_HTML });

  const remoteVideo = hook.el.querySelector("#remote-video");
  const remoteAudio = hook.el.querySelector("#remote-audio");
  const localVideo = hook.el.querySelector("#local-video");
  vi.spyOn(remoteVideo, "play").mockResolvedValue(undefined);
  vi.spyOn(remoteAudio, "play").mockResolvedValue(undefined);
  vi.spyOn(localVideo, "play").mockResolvedValue(undefined);

  const firePcReady = (pc) => {
    webrtcEl.dispatchEvent(new CustomEvent(CONFIG.pcReadyEvent, { detail: { pc } }));
    return pc;
  };

  const click = (action) => {
    const button = hook.el.querySelector(`[data-media-action="${action}"]`);
    button.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  };

  return {
    hook,
    webrtcEl,
    recoverEvents,
    sourceEvents,
    remoteVideo,
    remoteAudio,
    localVideo,
    firePcReady,
    click,
  };
}

describe("createRtcMediaHook (black-box)", () => {
  let ctx;

  beforeEach(() => {
    vi.stubGlobal("MediaStream", FakeMediaStream);
    stubMediaDevices();
  });

  afterEach(() => {
    if (ctx?.hook) ctx.hook.destroyed();
    ctx = null;
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
    document.body.innerHTML = "";
  });

  it("registers the configured server-event handlers and signals readiness on mount", () => {
    ctx = setup();

    for (const eventName of Object.values(CONFIG.serverEvents)) {
      expect(ctx.hook.__eventHandlers[eventName]).toBeDefined();
    }
    expect(getPushEvents(ctx.hook, "media_ready")).toEqual([{}]);
  });

  it("starts a video call by publishing local tracks to the peer connection", async () => {
    ctx = setup();
    const pc = ctx.firePcReady(new FakeRTCPeerConnection());

    simulateEvent(ctx.hook, "start_video", {});

    await vi.waitFor(() => {
      const kinds = pc
        .getSenders()
        .map((sender) => sender.track?.kind)
        .filter(Boolean)
        .sort();
      expect(kinds).toEqual(["audio", "video"]);
    });

    expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalledWith(
      expect.objectContaining({ audio: expect.anything(), video: expect.anything() }),
    );
    expect(getPushEvents(ctx.hook, "call_started")).toContainEqual({
      type: "video",
      audio_on: true,
      video_on: true,
    });
  });

  it("queues an auto-start until the peer connection becomes ready", async () => {
    ctx = setup();

    // No peer connection yet: the start is queued, not attempted.
    simulateEvent(ctx.hook, "start_video", { auto: true });
    expect(navigator.mediaDevices.getUserMedia).not.toHaveBeenCalled();

    const pc = ctx.firePcReady(new FakeRTCPeerConnection());

    await vi.waitFor(() => {
      expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalled();
      const kinds = pc
        .getSenders()
        .map((sender) => sender.track?.kind)
        .filter(Boolean)
        .sort();
      expect(kinds).toEqual(["audio", "video"]);
    });
  });

  it("attaches a received remote track to the media elements", async () => {
    ctx = setup();
    const pc = ctx.firePcReady(new FakeRTCPeerConnection());

    // Simulate the browser firing the ontrack the hook wired onto the connection.
    pc.ontrack({ track: makeTrack("video", "remote-v"), streams: [] });
    pc.ontrack({ track: makeTrack("audio", "remote-a"), streams: [] });

    await vi.waitFor(() => {
      expect(ctx.remoteVideo.srcObject).toBeTruthy();
    });

    expect(ctx.remoteVideo.muted).toBe(true);
    expect(ctx.remoteVideo.autoplay).toBe(true);
    expect(ctx.remoteVideo.play).toHaveBeenCalled();
    expect(ctx.remoteAudio.srcObject).toBe(ctx.remoteVideo.srcObject);
    expect(ctx.remoteAudio.muted).toBe(false);
    expect(ctx.remoteAudio.play).toHaveBeenCalled();
  });

  it("adopts remote tracks arriving in separate streams into one stable stream", () => {
    ctx = setup();
    const pc = ctx.firePcReady(new FakeRTCPeerConnection());

    pc.ontrack({ track: makeTrack("video", "remote-v"), streams: [] });
    const firstStream = ctx.remoteVideo.srcObject;
    expect(firstStream).toBeTruthy();

    pc.ontrack({ track: makeTrack("audio", "remote-a"), streams: [] });

    // The element must keep its stream object (swapping it reloads the pipeline)
    // while still gaining the newly arrived track.
    expect(ctx.remoteVideo.srcObject).toBe(firstStream);
    expect(ctx.remoteVideo.srcObject.getVideoTracks()).toHaveLength(1);
    expect(ctx.remoteVideo.srcObject.getAudioTracks()).toHaveLength(1);
  });

  it("toggles screen sharing on and off through the control button", async () => {
    ctx = setup();
    const pc = ctx.firePcReady(new FakeRTCPeerConnection());

    simulateEvent(ctx.hook, "start_video", {});
    await vi.waitFor(() => {
      expect(pc.getSenders().some((sender) => sender.track?.kind === "video")).toBe(true);
    });

    const cameraTrack = pc.getSenders().find((sender) => sender.track?.kind === "video").track;
    const videoSender = pc.getSenders().find((sender) => sender.track?.kind === "video");
    const screenTrack = makeTrack("video", "screen-track");
    navigator.mediaDevices.getDisplayMedia.mockResolvedValue({
      id: "screen-stream",
      getTracks: () => [screenTrack],
      getVideoTracks: () => [screenTrack],
      getAudioTracks: () => [],
    });

    ctx.click("screen-share");

    await vi.waitFor(() => {
      expect(getPushEvents(ctx.hook, "screen_share_changed")).toContainEqual({ active: true });
    });
    expect(videoSender.replaceTrack).toHaveBeenCalledWith(screenTrack);
    expect(ctx.sourceEvents.at(-1).detail).toEqual({ source: "screen" });

    ctx.click("screen-share");

    await vi.waitFor(() => {
      expect(getPushEvents(ctx.hook, "screen_share_changed")).toContainEqual({ active: false });
    });
    expect(videoSender.replaceTrack).toHaveBeenCalledWith(cameraTrack);
    expect(screenTrack.stop).toHaveBeenCalled();
    expect(ctx.sourceEvents.at(-1).detail).toEqual({ source: "camera" });
  });

  it("republishes local tracks onto a replacement peer connection", async () => {
    ctx = setup();
    const pc1 = ctx.firePcReady(new FakeRTCPeerConnection());

    simulateEvent(ctx.hook, "start_video", {});
    await vi.waitFor(() => {
      expect(pc1.getSenders().filter((sender) => sender.track).length).toBe(2);
    });

    // A reconnect swaps the connection; the hook must move its live local tracks
    // onto the new one without another getUserMedia.
    navigator.mediaDevices.getUserMedia.mockClear();
    const pc2 = ctx.firePcReady(new FakeRTCPeerConnection());

    await vi.waitFor(() => {
      const kinds = pc2
        .getSenders()
        .map((sender) => sender.track?.kind)
        .filter(Boolean)
        .sort();
      expect(kinds).toEqual(["audio", "video"]);
    });
    expect(navigator.mediaDevices.getUserMedia).not.toHaveBeenCalled();
  });

  it("ends the call from the control button, stopping local tracks and notifying", async () => {
    ctx = setup();
    const pc = ctx.firePcReady(new FakeRTCPeerConnection());

    simulateEvent(ctx.hook, "start_video", {});
    await vi.waitFor(() => {
      expect(pc.getSenders().filter((sender) => sender.track).length).toBe(2);
    });

    const localTracks = pc.getSenders().map((sender) => sender.track);

    ctx.click("end-call");

    for (const track of localTracks) {
      expect(track.stop).toHaveBeenCalled();
    }
    expect(getPushEvents(ctx.hook, "call_ended")).toContainEqual({ reason: "ended" });
  });
});
