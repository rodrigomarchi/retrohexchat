import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import GameWebRTCHook from "../../../js/hooks/games/game_webrtc_hook.js";

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
    this.ondatachannel = null;
    this.signalingState = "stable";
    this.transceivers = [];
  }

  createDataChannel(label, options) {
    return new MockDataChannel(label, options);
  }

  async createOffer() {
    return { type: "offer", sdp: "mock-sdp" };
  }

  async createAnswer() {
    return { type: "answer", sdp: "mock-answer-sdp" };
  }

  async setLocalDescription(desc) {
    this.localDescription = desc;
  }

  async setRemoteDescription(desc) {
    this.remoteDescription = desc;
  }

  async addIceCandidate() {}

  addTransceiver(kind, options) {
    const transceiver = {
      direction: options?.direction,
      receiver: { track: { kind } },
      sender: { track: null },
    };
    this.transceivers.push(transceiver);
    return transceiver;
  }

  getTransceivers() {
    return this.transceivers;
  }

  close() {
    this.connectionState = "closed";
  }
}

function createHookContext() {
  const pushEventCalls = [];
  return {
    el: document.createElement("div"),
    pushEvent: vi.fn((event, payload) => pushEventCalls.push({ event, payload })),
    handleEvent: vi.fn(),
    pushEventCalls,
  };
}

describe("GameWebRTCHook", () => {
  let originalRTC;

  beforeEach(() => {
    originalRTC = globalThis.RTCPeerConnection;
    globalThis.RTCPeerConnection = MockRTCPeerConnection;
  });

  afterEach(() => {
    globalThis.RTCPeerConnection = originalRTC;
  });

  describe("mounted", () => {
    it("registers game-prefixed event handlers", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      expect(ctx.handleEvent).toHaveBeenCalledWith("game_start_offer", expect.any(Function));
      expect(ctx.handleEvent).toHaveBeenCalledWith("game_start_answer", expect.any(Function));
      expect(ctx.handleEvent).toHaveBeenCalledWith("game_signal", expect.any(Function));
      expect(ctx.handleEvent).toHaveBeenCalledWith("game_renegotiate", expect.any(Function));
    });

    it("initializes state to null/0", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      expect(hook.pc).toBeNull();
      expect(hook.iceServers).toBeNull();
      expect(hook.retryCount).toBe(0);
      expect(hook.dataChannel).toBeNull();
      expect(hook.role).toBeNull();
    });
  });

  describe("game_start_offer flow", () => {
    it("creates peer connection and pushes offer signal", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_start_offer");
      await startOfferCall[1]({ ice_servers: [{ urls: "stun:localhost" }] });

      await vi.waitFor(() => {
        expect(ctx.pushEvent).toHaveBeenCalledWith(
          "game_signal",
          expect.objectContaining({ type: "offer" }),
        );
      });
    });

    it("creates a gamedata DataChannel as initiator", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_start_offer");
      await startOfferCall[1]({ ice_servers: [] });

      expect(hook.dataChannel).not.toBeNull();
      expect(hook.dataChannel.label).toBe("gamedata");
      expect(hook.dataChannel.ordered).toBe(true);
      expect(hook.dataChannel.binaryType).toBe("arraybuffer");
    });
  });

  describe("game_start_answer flow", () => {
    it("stores ICE servers and sets role to answerer", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startAnswerCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_start_answer");
      startAnswerCall[1]({
        ice_servers: [{ urls: "turn:localhost:3478" }],
      });

      expect(hook.iceServers).toEqual([{ urls: "turn:localhost:3478" }]);
      expect(hook.role).toBe("answerer");
    });
  });

  describe("game_signal dispatch", () => {
    it("handles incoming offer by creating answer", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startAnswerCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_start_answer");
      startAnswerCall[1]({ ice_servers: [] });

      const signalCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_signal");
      await signalCall[1]({ type: "offer", sdp: "remote-offer" });

      await vi.waitFor(() => {
        expect(ctx.pushEvent).toHaveBeenCalledWith(
          "game_signal",
          expect.objectContaining({ type: "answer" }),
        );
      });
    });
  });

  describe("connection state changes", () => {
    it("pushes game_rtc_state on state transitions", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook._handleConnectionStateChange("connecting");

      expect(ctx.pushEvent).toHaveBeenCalledWith("game_rtc_state", {
        state: "connecting",
      });
    });

    it("pushes game_connected and resets retryCount on connected", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook.retryCount = 2;
      hook._handleConnectionStateChange("connected");

      expect(ctx.pushEvent).toHaveBeenCalledWith("game_connected", {});
      expect(hook.retryCount).toBe(0);
    });

    it("exposes PeerConnection for GameMediaHook on connected", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);
      const events = [];
      hook.el.addEventListener("game_media_pc_ready", (event) => events.push(event));

      hook.mounted();
      hook.pc = new MockRTCPeerConnection();
      hook._handleConnectionStateChange("connected");

      expect(hook.el._peerConnection).toBe(hook.pc);
      expect(events).toHaveLength(1);
      expect(events[0].detail.pc).toBe(hook.pc);
    });

    it("starts disconnected grace period on disconnected state", () => {
      vi.useFakeTimers();
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook._handleConnectionStateChange("disconnected");

      expect(hook.disconnectedTimer).not.toBeNull();

      vi.useRealTimers();
    });
  });

  describe("retry logic", () => {
    it("retries on failure when retryCount < maxAttempts", () => {
      vi.useFakeTimers();
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook.role = "initiator";
      hook.iceServers = [];
      hook.retryCount = 0;

      hook._handleFailure();

      expect(ctx.pushEvent).toHaveBeenCalledWith("game_rtc_retry", {
        attempt: 1,
      });
      expect(hook.retryCount).toBe(1);

      vi.useRealTimers();
    });

    it("pushes game_rtc_failed after max retries", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook.retryCount = 3;

      hook._handleFailure();

      expect(ctx.pushEvent).toHaveBeenCalledWith("game_rtc_failed", {
        reason: "max_retries_exhausted",
      });
    });
  });

  describe("DataChannel events", () => {
    it("dispatches game_channel_ready on DataChannel open", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_start_offer");
      await startOfferCall[1]({ ice_servers: [] });

      const events = [];
      hook.el.addEventListener("game_channel_ready", (e) => events.push(e));

      hook.dataChannel.onopen();

      expect(events.length).toBe(1);
      expect(events[0].detail.channel).toBe(hook.dataChannel);
    });

    it("stores channel on element for late-mounting hooks", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_start_offer");
      await startOfferCall[1]({ ice_servers: [] });

      hook.dataChannel.onopen();
      expect(hook.el._gameDataChannel).toBe(hook.dataChannel);
    });

    it("clears channel on element when DataChannel closes", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_start_offer");
      await startOfferCall[1]({ ice_servers: [] });

      hook.dataChannel.onopen();
      expect(hook.el._gameDataChannel).toBe(hook.dataChannel);

      hook.dataChannel.onclose();
      expect(hook.el._gameDataChannel).toBeNull();
    });
  });

  describe("media renegotiation", () => {
    it("creator renegotiates by pushing a fresh offer", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook.role = "initiator";
      hook.pc = new MockRTCPeerConnection();

      const renegotiateCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_renegotiate");
      await renegotiateCall[1]({});

      expect(ctx.pushEvent).toHaveBeenCalledWith(
        "game_signal",
        expect.objectContaining({ type: "offer" }),
      );
    });

    it("answerer ignores explicit renegotiation requests", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook.role = "answerer";
      hook.pc = new MockRTCPeerConnection();

      const renegotiateCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_renegotiate");
      await renegotiateCall[1]({});

      expect(ctx.pushEvent).not.toHaveBeenCalledWith(
        "game_signal",
        expect.objectContaining({ type: "offer" }),
      );
    });

    it("creator prepares receiving transceivers for peer-started video before offer", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook.role = "initiator";
      hook.pc = new MockRTCPeerConnection();

      const renegotiateCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_renegotiate");
      await renegotiateCall[1]({ type: "video" });

      expect(
        hook.pc.getTransceivers().map((transceiver) => transceiver.receiver.track.kind),
      ).toEqual(["audio", "video"]);
      expect(hook.pc.getTransceivers().map((transceiver) => transceiver.direction)).toEqual([
        "recvonly",
        "recvonly",
      ]);
    });

    it("creator does not duplicate media transceivers on repeated renegotiation", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook.role = "initiator";
      hook.pc = new MockRTCPeerConnection();

      const renegotiateCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_renegotiate");
      await renegotiateCall[1]({ type: "video" });
      await renegotiateCall[1]({ type: "video" });

      expect(hook.pc.getTransceivers()).toHaveLength(2);
    });
  });

  describe("destroyed", () => {
    it("closes peer connection and clears DataChannel", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_start_offer");
      await startOfferCall[1]({ ice_servers: [] });

      expect(hook.dataChannel).not.toBeNull();
      expect(hook.pc).not.toBeNull();

      hook.destroyed();

      expect(hook.dataChannel).toBeNull();
      expect(hook.pc).toBeNull();
      expect(hook.el._peerConnection).toBeNull();
    });

    it("dispatches game_media_pc_closed during cleanup", async () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);
      const events = [];
      hook.el.addEventListener("game_media_pc_closed", (event) => events.push(event));

      hook.mounted();
      hook.pc = new MockRTCPeerConnection();
      hook.destroyed();

      expect(events).toHaveLength(1);
    });

    it("handles destroy without peer connection", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameWebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      expect(() => hook.destroyed()).not.toThrow();
    });
  });
});
