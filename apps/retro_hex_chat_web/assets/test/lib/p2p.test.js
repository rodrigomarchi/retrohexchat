import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { detectCapabilities, requestPermission } from "../../js/lib/p2p";

describe("detectCapabilities", () => {
  let originalRTC;
  let originalMediaDevices;

  beforeEach(() => {
    originalRTC = globalThis.RTCPeerConnection;
    originalMediaDevices = navigator.mediaDevices;
  });

  afterEach(() => {
    globalThis.RTCPeerConnection = originalRTC;
    Object.defineProperty(navigator, "mediaDevices", {
      value: originalMediaDevices,
      writable: true,
      configurable: true,
    });
  });

  it("detects all capabilities when available", async () => {
    globalThis.RTCPeerConnection = function () {};
    globalThis.RTCPeerConnection.prototype.createDataChannel = function () {};

    Object.defineProperty(navigator, "mediaDevices", {
      value: { getUserMedia: vi.fn() },
      writable: true,
      configurable: true,
    });

    const result = await detectCapabilities();
    expect(result.webrtc).toBe(true);
    expect(result.getUserMedia).toBe(true);
    expect(result.dataChannel).toBe(true);
  });

  it("detects missing RTCPeerConnection", async () => {
    globalThis.RTCPeerConnection = undefined;

    Object.defineProperty(navigator, "mediaDevices", {
      value: { getUserMedia: vi.fn() },
      writable: true,
      configurable: true,
    });

    const result = await detectCapabilities();
    expect(result.webrtc).toBe(false);
    expect(result.dataChannel).toBe(false);
  });

  it("detects missing getUserMedia", async () => {
    globalThis.RTCPeerConnection = function () {};
    globalThis.RTCPeerConnection.prototype.createDataChannel = function () {};

    Object.defineProperty(navigator, "mediaDevices", {
      value: undefined,
      writable: true,
      configurable: true,
    });

    const result = await detectCapabilities();
    expect(result.getUserMedia).toBe(false);
  });
});

describe("requestPermission", () => {
  let originalMediaDevices;

  beforeEach(() => {
    originalMediaDevices = navigator.mediaDevices;
  });

  afterEach(() => {
    Object.defineProperty(navigator, "mediaDevices", {
      value: originalMediaDevices,
      writable: true,
      configurable: true,
    });
  });

  it("returns granted: true when permission allowed", async () => {
    const mockTrack = { stop: vi.fn() };
    const mockStream = { getTracks: () => [mockTrack] };

    Object.defineProperty(navigator, "mediaDevices", {
      value: { getUserMedia: vi.fn().mockResolvedValue(mockStream) },
      writable: true,
      configurable: true,
    });

    const result = await requestPermission("microphone");
    expect(result).toEqual({ granted: true, type: "microphone" });
    expect(mockTrack.stop).toHaveBeenCalled();
  });

  it("returns granted: false when permission denied", async () => {
    Object.defineProperty(navigator, "mediaDevices", {
      value: {
        getUserMedia: vi.fn().mockRejectedValue(new Error("NotAllowedError")),
      },
      writable: true,
      configurable: true,
    });

    const result = await requestPermission("microphone");
    expect(result).toEqual({ granted: false, type: "microphone" });
  });

  it("requests video for camera type", async () => {
    const mockTrack = { stop: vi.fn() };
    const mockStream = { getTracks: () => [mockTrack] };
    const mockGetUserMedia = vi.fn().mockResolvedValue(mockStream);

    Object.defineProperty(navigator, "mediaDevices", {
      value: { getUserMedia: mockGetUserMedia },
      writable: true,
      configurable: true,
    });

    await requestPermission("camera");
    expect(mockGetUserMedia).toHaveBeenCalledWith({ video: true });
  });

  it("requests audio for microphone type", async () => {
    const mockTrack = { stop: vi.fn() };
    const mockStream = { getTracks: () => [mockTrack] };
    const mockGetUserMedia = vi.fn().mockResolvedValue(mockStream);

    Object.defineProperty(navigator, "mediaDevices", {
      value: { getUserMedia: mockGetUserMedia },
      writable: true,
      configurable: true,
    });

    await requestPermission("microphone");
    expect(mockGetUserMedia).toHaveBeenCalledWith({ audio: true });
  });
});
