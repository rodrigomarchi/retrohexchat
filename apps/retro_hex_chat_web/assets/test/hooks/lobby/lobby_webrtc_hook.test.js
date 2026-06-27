import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import LobbyWebRTCHook from "../../../js/hooks/lobby/lobby_webrtc_hook.js";

class MockDataChannel {
  constructor(label, options) {
    this.label = label;
    this.ordered = options?.ordered ?? true;
    this.readyState = "connecting";
    this.binaryType = "arraybuffer";
    this.onopen = null;
    this.onclose = null;
    this.onmessage = null;
  }
}

class MockRTCPeerConnection {
  constructor() {
    this.localDescription = null;
    this.remoteDescription = null;
    this.connectionState = "new";
    this.onconnectionstatechange = null;
    this.onicecandidate = null;
    this.onnegotiationneeded = null;
    this.onicecandidateerror = null;
    this.ondatachannel = null;
  }

  createDataChannel(label, options) {
    return new MockDataChannel(label, options);
  }

  async createOffer() {
    return { type: "offer", sdp: "mock-sdp" };
  }

  async setLocalDescription(desc) {
    this.localDescription = desc;
  }

  async getStats() {
    return new Map();
  }

  close() {
    this.connectionState = "closed";
  }
}

function buildHook() {
  const ctx = {
    el: document.createElement("div"),
    pushEvent: vi.fn(),
    handleEvent: vi.fn(),
  };
  const hook = Object.assign(Object.create(LobbyWebRTCHook), ctx);
  hook.mounted();
  return hook;
}

describe("LobbyWebRTCHook", () => {
  let originalRTC;

  beforeEach(() => {
    originalRTC = globalThis.RTCPeerConnection;
    globalThis.RTCPeerConnection = MockRTCPeerConnection;
  });

  afterEach(() => {
    globalThis.RTCPeerConnection = originalRTC;
  });

  it("creates both the filetransfer and game data channels as initiator", async () => {
    const hook = buildHook();
    hook.role = "initiator";
    hook.iceServers = [];

    await hook._createConnection();

    expect(hook.fileChannel.label).toBe("filetransfer");
    expect(hook.gameChannel.label).toBe("gamedata");
  });

  it("routes an inbound gamedata channel to game_channel_ready", () => {
    const hook = buildHook();
    const channel = new MockDataChannel("gamedata", {});

    let gameReady = null;
    hook.el.addEventListener("game_channel_ready", (e) => (gameReady = e.detail.channel));

    hook._adoptChannel(channel);
    channel.onopen();

    expect(gameReady).toBe(channel);
    expect(hook.el._gameDataChannel).toBe(channel);
  });

  it("routes an inbound filetransfer channel to ft_channel_ready", () => {
    const hook = buildHook();
    const channel = new MockDataChannel("filetransfer", {});

    let ftReady = null;
    hook.el.addEventListener("ft_channel_ready", (e) => (ftReady = e.detail.channel));

    hook._adoptChannel(channel);
    channel.onopen();

    expect(ftReady).toBe(channel);
    expect(hook.el._fileTransferChannel).toBe(channel);
  });

  it("samples and pushes an always-complete per-feature lobby_stats payload", async () => {
    const hook = buildHook();
    hook.role = "initiator";
    hook.iceServers = [];
    await hook._createConnection();
    hook.pc.connectionState = "connected";

    await hook._sampleStats();

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "lobby_stats",
      expect.objectContaining({
        connection: expect.any(Object),
        audio: expect.any(Object),
        video: expect.any(Object),
        game: expect.any(Object),
        file: expect.any(Object),
      }),
    );
  });

  it("stops the stats poller on cleanup", () => {
    const hook = buildHook();
    hook.statsTimer = setInterval(() => {}, 1000);

    hook._stopStatsPolling();

    expect(hook.statsTimer).toBeNull();
  });
});
