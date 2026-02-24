import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  createPeerConnection,
  createOffer,
  createAnswer,
  handleAnswer,
  addIceCandidate,
  close,
  onConnectionStateChange,
  onIceCandidate,
  onDataChannel,
  RETRY_CONFIG,
} from "../../../js/lib/p2p/webrtc.js";

class MockRTCPeerConnection {
  constructor(config) {
    this.config = config;
    this.localDescription = null;
    this.remoteDescription = null;
    this.connectionState = "new";
    this.onconnectionstatechange = null;
    this.onicecandidate = null;
    this.ondatachannel = null;
    this._closed = false;
  }

  async createOffer() {
    return { type: "offer", sdp: "mock-offer-sdp" };
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

  async addIceCandidate(candidate) {
    this._lastCandidate = candidate;
  }

  close() {
    this._closed = true;
    this.connectionState = "closed";
  }
}

describe("webrtc.js", () => {
  let originalRTC;

  beforeEach(() => {
    originalRTC = globalThis.RTCPeerConnection;
    globalThis.RTCPeerConnection = MockRTCPeerConnection;
  });

  afterEach(() => {
    globalThis.RTCPeerConnection = originalRTC;
  });

  describe("createPeerConnection", () => {
    it("creates RTCPeerConnection with ICE servers", () => {
      const iceServers = [{ urls: "turn:localhost:3478" }];
      const pc = createPeerConnection(iceServers);

      expect(pc).toBeInstanceOf(MockRTCPeerConnection);
      expect(pc.config.iceServers).toEqual(iceServers);
    });

    it("sets iceTransportPolicy to relay when turnOnly is true", () => {
      const iceServers = [{ urls: "turn:localhost:3478" }];
      const pc = createPeerConnection(iceServers, { turnOnly: true });

      expect(pc.config.iceTransportPolicy).toBe("relay");
    });

    it("does not set iceTransportPolicy when turnOnly is false", () => {
      const iceServers = [{ urls: "turn:localhost:3478" }];
      const pc = createPeerConnection(iceServers, { turnOnly: false });

      expect(pc.config.iceTransportPolicy).toBeUndefined();
    });

    it("does not set iceTransportPolicy when options omitted", () => {
      const iceServers = [{ urls: "turn:localhost:3478" }];
      const pc = createPeerConnection(iceServers);

      expect(pc.config.iceTransportPolicy).toBeUndefined();
    });
  });

  describe("createOffer", () => {
    it("creates offer and sets local description", async () => {
      const pc = createPeerConnection([]);
      const offer = await createOffer(pc);

      expect(offer.type).toBe("offer");
      expect(offer.sdp).toBe("mock-offer-sdp");
      expect(pc.localDescription).toEqual(offer);
    });
  });

  describe("createAnswer", () => {
    it("sets remote offer and creates answer", async () => {
      const pc = createPeerConnection([]);
      const offer = { type: "offer", sdp: "remote-offer" };
      const answer = await createAnswer(pc, offer);

      expect(pc.remoteDescription).toEqual(offer);
      expect(answer.type).toBe("answer");
      expect(answer.sdp).toBe("mock-answer-sdp");
      expect(pc.localDescription).toEqual(answer);
    });
  });

  describe("handleAnswer", () => {
    it("sets remote answer", async () => {
      const pc = createPeerConnection([]);
      const answer = { type: "answer", sdp: "remote-answer" };
      await handleAnswer(pc, answer);

      expect(pc.remoteDescription).toEqual(answer);
    });
  });

  describe("addIceCandidate", () => {
    it("adds ICE candidate to peer connection", async () => {
      const pc = createPeerConnection([]);
      const candidate = { candidate: "candidate:1 1 udp ..." };
      await addIceCandidate(pc, candidate);

      expect(pc._lastCandidate).toEqual(candidate);
    });
  });

  describe("close", () => {
    it("closes the peer connection", () => {
      const pc = createPeerConnection([]);
      close(pc);

      expect(pc._closed).toBe(true);
    });
  });

  describe("onConnectionStateChange", () => {
    it("registers callback for state changes", () => {
      const pc = createPeerConnection([]);
      const callback = vi.fn();
      onConnectionStateChange(pc, callback);

      expect(pc.onconnectionstatechange).toBeDefined();

      pc.connectionState = "connected";
      pc.onconnectionstatechange();
      expect(callback).toHaveBeenCalledWith("connected");
    });
  });

  describe("onIceCandidate", () => {
    it("registers callback for ICE candidates", () => {
      const pc = createPeerConnection([]);
      const callback = vi.fn();
      onIceCandidate(pc, callback);

      expect(pc.onicecandidate).toBeDefined();

      const event = { candidate: { candidate: "test" } };
      pc.onicecandidate(event);
      expect(callback).toHaveBeenCalledWith(event.candidate);
    });

    it("calls callback with null when gathering complete", () => {
      const pc = createPeerConnection([]);
      const callback = vi.fn();
      onIceCandidate(pc, callback);

      pc.onicecandidate({ candidate: null });
      expect(callback).toHaveBeenCalledWith(null);
    });
  });

  describe("onDataChannel", () => {
    it("registers callback for data channels", () => {
      const pc = createPeerConnection([]);
      const callback = vi.fn();
      onDataChannel(pc, callback);

      expect(pc.ondatachannel).toBeDefined();

      const event = { channel: {} };
      pc.ondatachannel(event);
      expect(callback).toHaveBeenCalledWith(event.channel);
    });
  });

  describe("RETRY_CONFIG", () => {
    it("exports retry configuration", () => {
      expect(RETRY_CONFIG.maxAttempts).toBe(3);
      expect(RETRY_CONFIG.delays).toEqual([2000, 4000, 8000]);
      expect(RETRY_CONFIG.disconnectedGracePeriod).toBe(5000);
    });
  });
});
