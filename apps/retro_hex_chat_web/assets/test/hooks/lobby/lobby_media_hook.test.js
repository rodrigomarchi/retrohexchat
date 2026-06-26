import { describe, it, expect, vi, afterEach } from "vitest";
import LobbyMediaHook from "../../../js/hooks/lobby/lobby_media_hook.js";

// Exercises the lobby-only behaviours layered on the shared RTC media factory:
// recvonly auto-join and the stalled-media watchdog.

function setup() {
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
    querySelector: vi.fn(() => null),
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
});
