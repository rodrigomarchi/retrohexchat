import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import WebRTCHook from "../../../js/hooks/p2p/webrtc_hook.js";

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

describe("WebRTCHook", () => {
  let originalRTC;

  beforeEach(() => {
    originalRTC = globalThis.RTCPeerConnection;
    globalThis.RTCPeerConnection = MockRTCPeerConnection;
  });

  afterEach(() => {
    globalThis.RTCPeerConnection = originalRTC;
  });

  describe("mounted", () => {
    it("registers event handlers", () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      expect(ctx.handleEvent).toHaveBeenCalledWith("p2p_start_offer", expect.any(Function));
      expect(ctx.handleEvent).toHaveBeenCalledWith("p2p_start_answer", expect.any(Function));
      expect(ctx.handleEvent).toHaveBeenCalledWith("p2p_signal", expect.any(Function));
    });
  });

  describe("p2p_start_offer flow", () => {
    it("creates peer connection and pushes offer", async () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      // Find the p2p_start_offer handler
      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_start_offer");
      const handler = startOfferCall[1];

      await handler({ ice_servers: [{ urls: "stun:localhost:3478" }] });

      // Should have pushed the offer signal
      await vi.waitFor(() => {
        expect(ctx.pushEvent).toHaveBeenCalledWith(
          "p2p_signal",
          expect.objectContaining({ type: "offer" }),
        );
      });
    });
  });

  describe("p2p_start_answer flow", () => {
    it("stores ICE servers and waits for offer", () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startAnswerCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_start_answer");
      const handler = startAnswerCall[1];

      handler({ ice_servers: [{ urls: "turn:localhost:3478" }] });

      expect(hook.iceServers).toEqual([{ urls: "turn:localhost:3478" }]);
    });
  });

  describe("p2p_signal dispatch", () => {
    it("handles incoming offer by creating answer", async () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      // First set up as answerer
      const startAnswerCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_start_answer");
      startAnswerCall[1]({ ice_servers: [] });

      // Then receive offer signal
      const signalCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_signal");
      await signalCall[1]({ type: "offer", sdp: "remote-offer" });

      await vi.waitFor(() => {
        expect(ctx.pushEvent).toHaveBeenCalledWith(
          "p2p_signal",
          expect.objectContaining({ type: "answer" }),
        );
      });
    });
  });

  describe("connection state change (T035)", () => {
    it("pushes p2p_state_change on connectionState transitions", async () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      // Simulate _handleConnectionStateChange
      hook._handleConnectionStateChange("connecting");

      expect(ctx.pushEvent).toHaveBeenCalledWith("p2p_state_change", {
        state: "connecting",
      });
    });

    it("pushes p2p_connected on connected state", () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      hook._handleConnectionStateChange("connected");

      expect(ctx.pushEvent).toHaveBeenCalledWith("p2p_connected", {});
    });
  });

  describe("retry logic (T030)", () => {
    it("retries on failed state when retryCount < maxAttempts", () => {
      vi.useFakeTimers();
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook.role = "initiator";
      hook.iceServers = [];
      hook.retryCount = 0;

      hook._handleFailure();

      expect(ctx.pushEvent).toHaveBeenCalledWith("p2p_retry", { attempt: 1 });
      expect(hook.retryCount).toBe(1);

      vi.useRealTimers();
    });

    it("pushes p2p_failed after max retries exhausted", () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook.retryCount = 3; // Already at max

      hook._handleFailure();

      expect(ctx.pushEvent).toHaveBeenCalledWith("p2p_failed", {
        reason: "max_retries_exhausted",
      });
    });

    it("resets retryCount on successful connection", () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook.retryCount = 2;

      hook._handleConnectionStateChange("connected");

      expect(hook.retryCount).toBe(0);
    });

    it("starts disconnected grace period on disconnected state", () => {
      vi.useFakeTimers();
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();
      hook.retryCount = 0;

      hook._handleConnectionStateChange("disconnected");

      expect(hook.disconnectedTimer).not.toBeNull();

      vi.useRealTimers();
    });
  });

  describe("DataChannel creation (T049)", () => {
    it("initiator creates a filetransfer DataChannel", async () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_start_offer");
      await startOfferCall[1]({ ice_servers: [] });

      expect(hook.dataChannel).not.toBeNull();
      expect(hook.dataChannel.label).toBe("filetransfer");
      expect(hook.dataChannel.ordered).toBe(true);
      expect(hook.dataChannel.binaryType).toBe("arraybuffer");
    });

    it("answerer sets ondatachannel handler", async () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startAnswerCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_start_answer");
      startAnswerCall[1]({ ice_servers: [] });

      // Receive offer to create connection
      const signalCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_signal");
      await signalCall[1]({ type: "offer", sdp: "remote-offer" });

      expect(hook.pc.ondatachannel).toBeTypeOf("function");
    });

    it("dispatches ft_channel_ready on DataChannel open", async () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_start_offer");
      await startOfferCall[1]({ ice_servers: [] });

      const events = [];
      hook.el.addEventListener("ft_channel_ready", (e) => events.push(e));

      // Simulate channel open
      hook.dataChannel.onopen();

      expect(events.length).toBe(1);
      expect(events[0].detail.channel).toBe(hook.dataChannel);
    });

    it("stores channel reference on element for late-mounting hooks", async () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_start_offer");
      await startOfferCall[1]({ ice_servers: [] });

      // Simulate channel open
      hook.dataChannel.onopen();

      expect(hook.el._fileTransferChannel).toBe(hook.dataChannel);
    });

    it("clears channel reference on element when DataChannel closes", async () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_start_offer");
      await startOfferCall[1]({ ice_servers: [] });

      hook.dataChannel.onopen();
      expect(hook.el._fileTransferChannel).toBe(hook.dataChannel);

      hook.dataChannel.onclose();
      expect(hook.el._fileTransferChannel).toBeNull();
    });

    it("dispatches ft_channel_closed on DataChannel close", async () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_start_offer");
      await startOfferCall[1]({ ice_servers: [] });

      const events = [];
      hook.el.addEventListener("ft_channel_closed", (e) => events.push(e));

      hook.dataChannel.onclose();

      expect(events.length).toBe(1);
    });

    it("cleans up DataChannel on destroy", async () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const startOfferCall = ctx.handleEvent.mock.calls.find((c) => c[0] === "p2p_start_offer");
      await startOfferCall[1]({ ice_servers: [] });

      expect(hook.dataChannel).not.toBeNull();

      hook.destroyed();

      expect(hook.dataChannel).toBeNull();
    });
  });

  describe("destroyed", () => {
    it("closes peer connection on destroy", () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      // Create a PC first
      hook.pc = new MockRTCPeerConnection();
      const closeSpy = vi.spyOn(hook.pc, "close");

      hook.destroyed();

      expect(closeSpy).toHaveBeenCalled();
    });

    it("handles destroy without peer connection", () => {
      const ctx = createHookContext();
      const hook = Object.create(WebRTCHook);
      Object.assign(hook, ctx);

      hook.mounted();

      expect(() => hook.destroyed()).not.toThrow();
    });
  });
});
