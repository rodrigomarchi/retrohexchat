import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import P2PCapabilityHook from "../../../js/hooks/p2p/p2p_capability_hook";

describe("P2PCapabilityHook", () => {
  let hook;
  let originalRTC;
  let originalMediaDevices;

  beforeEach(() => {
    originalRTC = globalThis.RTCPeerConnection;
    originalMediaDevices = navigator.mediaDevices;

    hook = {
      ...P2PCapabilityHook,
      pushEvent: vi.fn(),
      handleEvent: vi.fn(),
    };
  });

  afterEach(() => {
    globalThis.RTCPeerConnection = originalRTC;
    Object.defineProperty(navigator, "mediaDevices", {
      value: originalMediaDevices,
      writable: true,
      configurable: true,
    });
  });

  it("pushes capabilities on mount", async () => {
    globalThis.RTCPeerConnection = function () {};
    globalThis.RTCPeerConnection.prototype.createDataChannel = function () {};

    Object.defineProperty(navigator, "mediaDevices", {
      value: { getUserMedia: vi.fn() },
      writable: true,
      configurable: true,
    });

    hook.mounted();

    // Wait for async detectCapabilities to resolve
    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(hook.pushEvent).toHaveBeenCalledWith("p2p_capabilities", {
      webrtc: true,
      getUserMedia: true,
      dataChannel: true,
    });
  });

  it("registers p2p_request_permission event handler", () => {
    globalThis.RTCPeerConnection = undefined;
    Object.defineProperty(navigator, "mediaDevices", {
      value: undefined,
      writable: true,
      configurable: true,
    });

    hook.mounted();

    expect(hook.handleEvent).toHaveBeenCalledWith("p2p_request_permission", expect.any(Function));
  });
});
