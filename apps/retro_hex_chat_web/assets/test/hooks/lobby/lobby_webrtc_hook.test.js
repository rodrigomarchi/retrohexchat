import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import LobbyWebRTCHook from "../../../js/hooks/lobby/lobby_webrtc_hook.js";
import {
  FakeDataChannel as MockDataChannel,
  FakeRTCPeerConnection as MockRTCPeerConnection,
} from "../../helpers/rtc_peer_connection.js";

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

function activityStats({
  bytesReceived = 0,
  bytesSent = 0,
  packetsReceived = 0,
  packetsSent = 0,
  messagesReceived = 0,
  messagesSent = 0,
} = {}) {
  return new Map([
    [
      "candidate-pair",
      {
        type: "candidate-pair",
        state: "succeeded",
        bytesReceived,
        bytesSent,
        packetsReceived,
        packetsSent,
      },
    ],
    [
      "data",
      {
        type: "data-channel",
        bytesReceived: 0,
        bytesSent: 0,
        messagesReceived,
        messagesSent,
      },
    ],
  ]);
}

describe("LobbyWebRTCHook", () => {
  let originalRTC;

  beforeEach(() => {
    originalRTC = globalThis.RTCPeerConnection;
    globalThis.RTCPeerConnection = MockRTCPeerConnection;
  });

  afterEach(() => {
    vi.useRealTimers();
    globalThis.RTCPeerConnection = originalRTC;
    vi.restoreAllMocks();
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
    hook.pc.iceConnectionState = "connected";
    hook.signalingEpoch = 3;
    hook.currentOfferId = "p2p-3-1";
    hook.el.dispatchEvent(
      new CustomEvent("lobby_media_source_changed", { detail: { source: "screen" } }),
    );

    await hook._sampleStats();

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "lobby_stats",
      expect.objectContaining({
        connection: expect.any(Object),
        audio: expect.any(Object),
        video: expect.objectContaining({ source: "screen" }),
        game: expect.any(Object),
        file: expect.any(Object),
        summary: expect.objectContaining({
          connection_state: "connected",
          ice_connection_state: "connected",
          signaling_epoch: 3,
          offer_id: "p2p-3-1",
        }),
      }),
    );
  });

  it("stops the stats poller on cleanup", () => {
    const hook = buildHook();
    hook.statsTimer = setInterval(() => {}, 1000);

    hook._stopStatsPolling();

    expect(hook.statsTimer).toBeNull();
  });

  it("sends offers with epoch and offer id metadata", async () => {
    const hook = buildHook();
    hook.role = "initiator";
    hook.iceServers = [];
    await hook._createConnection();

    await hook._maybeOffer();

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "lobby_signal",
      expect.objectContaining({
        type: "offer",
        sdp: expect.any(String),
        epoch: 1,
        offer_id: "p2p-1-1",
        connection_reset: true,
      }),
    );
  });

  it("answerer auto-retry asks the initiator for a connection-reset offer", async () => {
    vi.useFakeTimers();
    const hook = buildHook();
    hook.role = "answerer";
    hook.iceServers = [];
    await hook._createConnection();

    hook._handleFailure();
    await vi.advanceTimersByTimeAsync(2000);

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "lobby_renegotiate",
      expect.objectContaining({
        recover: true,
        connection_reset: true,
        attempt: 1,
        reason: "auto_retry",
        epoch: 2,
      }),
    );

    vi.useRealTimers();
  });

  it("does not schedule overlapping automatic retries", async () => {
    vi.useFakeTimers();
    const hook = buildHook();
    hook.role = "initiator";
    hook.iceServers = [];
    await hook._createConnection();

    hook._handleFailure();
    hook._handleFailure();

    const retryEvents = hook.pushEvent.mock.calls.filter(([event]) => event === "lobby_retry");
    expect(retryEvents).toHaveLength(1);

    vi.useRealTimers();
  });

  it("uses ICE failed as a recovery signal", async () => {
    vi.useFakeTimers();
    const hook = buildHook();
    hook.role = "answerer";
    hook.iceServers = [];
    await hook._createConnection();

    hook.pc.iceConnectionState = "failed";
    hook.pc.oniceconnectionstatechange();
    await vi.advanceTimersByTimeAsync(2000);

    expect(hook.pushEvent).toHaveBeenCalledWith("lobby_retry", {
      attempt: 1,
      reason: "ice_failed",
    });
    expect(hook.pushEvent).toHaveBeenCalledWith(
      "lobby_renegotiate",
      expect.objectContaining({
        recover: true,
        connection_reset: true,
        reason: "ice_failed",
      }),
    );

    vi.useRealTimers();
  });

  it("requests signaling replay while startup remains unresolved", async () => {
    vi.useFakeTimers();
    const hook = buildHook();

    await hook._handleStartAnswer({ ice_servers: [], turn_only: false });
    hook.pushEvent.mockClear();

    await vi.advanceTimersByTimeAsync(1500);

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "lobby_signal_replay_request",
      expect.objectContaining({
        reason: "start_answer",
        attempt: 1,
        epoch: 1,
      }),
    );

    vi.useRealTimers();
  });

  it("applies signaling replay idempotently", async () => {
    vi.useFakeTimers();
    const hook = buildHook();
    const candidate = {
      candidate: "candidate:1 1 udp 1 127.0.0.1 9 typ host",
      sdpMid: "0",
      sdpMLineIndex: 0,
    };

    hook.role = "initiator";
    hook.iceServers = [];
    await hook._createConnection();
    await hook._maybeOffer();
    hook._clearSignalReplayTimer();

    const setRemoteDescription = vi.spyOn(hook.pc, "setRemoteDescription");
    const addIceCandidate = vi.spyOn(hook.pc, "addIceCandidate");

    await hook._handleSignalReplay({
      events: [
        {
          event: "lobby_signal",
          payload: { type: "answer", sdp: "answer-sdp", epoch: 1, offer_id: "p2p-1-1" },
        },
        {
          event: "lobby_signal",
          payload: { type: "answer", sdp: "answer-sdp", epoch: 1, offer_id: "p2p-1-1" },
        },
        { event: "lobby_signal", payload: { type: "ice-candidate", candidate, epoch: 1 } },
        { event: "lobby_signal", payload: { type: "ice-candidate", candidate, epoch: 1 } },
      ],
    });

    expect(setRemoteDescription).toHaveBeenCalledTimes(1);
    expect(addIceCandidate).toHaveBeenCalledTimes(1);

    vi.useRealTimers();
  });

  it("stands down and resyncs after the server rejects a signal as rate limited", async () => {
    vi.useFakeTimers();
    const hook = buildHook();

    hook.role = "initiator";
    hook.iceServers = [];
    await hook._createConnection();
    await hook._maybeOffer();

    hook.pushEvent.mockClear();
    hook._handleSignalRejected({ code: "rate_limited", retry_after_ms: 5000 });

    // Retrying inside the window the server named only spends the window.
    vi.advanceTimersByTime(4000);
    expect(hook.pushEvent).not.toHaveBeenCalledWith(
      "lobby_signal_replay_request",
      expect.anything(),
    );

    vi.advanceTimersByTime(1500);
    expect(hook.pushEvent).toHaveBeenCalledWith(
      "lobby_signal_replay_request",
      expect.objectContaining({ reason: "signal_rate_limited" }),
    );

    vi.useRealTimers();
  });

  it("retries answerer renegotiation requests until a new offer arrives", async () => {
    vi.useFakeTimers();
    const hook = buildHook();

    hook.role = "answerer";
    hook.iceServers = [];
    await hook._createConnection();
    hook.pushEvent.mockClear();

    hook._requestRenegotiation(true, { reason: "media_recover" });

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "lobby_renegotiate",
      expect.objectContaining({ recover: true, reason: "media_recover" }),
    );

    await vi.advanceTimersByTimeAsync(1200);

    const renegotiateEvents = () =>
      hook.pushEvent.mock.calls.filter(([event]) => event === "lobby_renegotiate");

    expect(renegotiateEvents()).toHaveLength(2);

    await hook._handleRemoteDescription({
      type: "offer",
      sdp: "fresh-offer",
      epoch: hook.signalingEpoch,
      offer_id: "p2p-1-2",
    });

    await vi.advanceTimersByTimeAsync(4000);

    expect(renegotiateEvents()).toHaveLength(2);

    vi.useRealTimers();
  });

  it("enters recovery when renegotiation requests are not answered", async () => {
    vi.useFakeTimers();
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const hook = buildHook();

    hook.role = "answerer";
    hook.iceServers = [];
    await hook._createConnection();
    hook.pushEvent.mockClear();

    hook._requestRenegotiation(true, { reason: "media_recover" });
    await vi.advanceTimersByTimeAsync(1200);
    await vi.advanceTimersByTimeAsync(2400);
    await vi.advanceTimersByTimeAsync(3600);

    expect(hook.pushEvent).toHaveBeenCalledWith("lobby_retry", {
      attempt: 1,
      reason: "renegotiate_request",
    });

    vi.useRealTimers();
  });

  it("recovers after repeated ICE candidate add failures and resets on success", async () => {
    vi.useFakeTimers();
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const hook = buildHook();
    const candidate = (index) => ({
      candidate: `candidate:${index} 1 udp 1 127.0.0.1 ${index} typ host`,
      sdpMid: "0",
      sdpMLineIndex: 0,
    });

    hook.role = "answerer";
    hook.iceServers = [];
    await hook._createConnection();
    hook.pc.remoteDescription = { type: "offer", sdp: "remote" };
    hook.pushEvent.mockClear();

    hook.pc.addIceCandidate = vi
      .fn()
      .mockRejectedValueOnce(new Error("ufrag mismatch"))
      .mockRejectedValueOnce(new Error("ufrag mismatch"))
      .mockResolvedValueOnce(undefined)
      .mockRejectedValue(new Error("ufrag mismatch"));

    await hook._handleRemoteCandidate({ candidate: candidate(1), epoch: hook.signalingEpoch });
    await hook._handleRemoteCandidate({ candidate: candidate(2), epoch: hook.signalingEpoch });

    expect(hook.pushEvent).not.toHaveBeenCalledWith("lobby_retry", expect.any(Object));

    await hook._handleRemoteCandidate({ candidate: candidate(3), epoch: hook.signalingEpoch });
    await hook._handleRemoteCandidate({ candidate: candidate(4), epoch: hook.signalingEpoch });
    await hook._handleRemoteCandidate({ candidate: candidate(5), epoch: hook.signalingEpoch });

    expect(hook.pushEvent).not.toHaveBeenCalledWith("lobby_retry", expect.any(Object));

    await hook._handleRemoteCandidate({ candidate: candidate(6), epoch: hook.signalingEpoch });

    expect(hook.pushEvent).toHaveBeenCalledWith("lobby_retry", {
      attempt: 1,
      reason: "ice_candidate",
    });

    vi.useRealTimers();
  });

  it("waits through transient ICE disconnected before retrying", async () => {
    vi.useFakeTimers();
    const hook = buildHook();
    hook.role = "initiator";
    hook.iceServers = [];
    await hook._createConnection();

    hook.pc.iceConnectionState = "disconnected";
    hook.pc.oniceconnectionstatechange();
    await vi.advanceTimersByTimeAsync(4999);

    expect(hook.pushEvent).toHaveBeenCalledWith("lobby_recovery_pending", {
      reason: "ice_disconnected",
    });
    expect(hook.pushEvent).not.toHaveBeenCalledWith("lobby_retry", expect.any(Object));

    hook.pc.iceConnectionState = "connected";
    hook.pc.oniceconnectionstatechange();
    await vi.advanceTimersByTimeAsync(10);

    expect(hook.pushEvent).not.toHaveBeenCalledWith("lobby_retry", expect.any(Object));

    vi.useRealTimers();
  });

  it("defers disconnected retry while getStats still shows activity", async () => {
    vi.useFakeTimers();
    const hook = buildHook();
    hook.role = "initiator";
    hook.iceServers = [];
    await hook._createConnection();
    hook.pc.statsQueue = [
      activityStats({ bytesReceived: 100, bytesSent: 50, packetsReceived: 2, packetsSent: 1 }),
      activityStats({ bytesReceived: 200, bytesSent: 50, packetsReceived: 3, packetsSent: 1 }),
      activityStats({ bytesReceived: 200, bytesSent: 50, packetsReceived: 3, packetsSent: 1 }),
    ];

    hook.pc.iceConnectionState = "disconnected";
    hook.pc.oniceconnectionstatechange();
    await vi.advanceTimersByTimeAsync(5000);

    expect(hook.pushEvent).toHaveBeenCalledWith("lobby_recovery_pending", {
      reason: "ice_disconnected",
    });
    expect(hook.pushEvent).not.toHaveBeenCalledWith("lobby_retry", expect.any(Object));

    await vi.advanceTimersByTimeAsync(5000);

    expect(hook.pushEvent).toHaveBeenCalledWith("lobby_retry", {
      attempt: 1,
      reason: "ice_disconnected",
    });

    vi.useRealTimers();
  });

  it("rebuilds with fresh ICE servers and relay policy from restart payload", async () => {
    const hook = buildHook();
    hook.role = "answerer";
    hook.iceServers = [{ urls: "stun:old.example.test" }];
    await hook._createConnection();
    const oldPc = hook.pc;

    await hook._handleRestart({
      ice_servers: [{ urls: "turn:relay.example.test" }],
      turn_only: true,
      reason: "signaling_snapshot_lost",
    });

    expect(oldPc.connectionState).toBe("closed");
    expect(hook.iceServers).toEqual([{ urls: "turn:relay.example.test" }]);
    expect(hook.turnOnly).toBe(true);
    expect(hook.pc.config).toEqual({
      iceServers: [{ urls: "turn:relay.example.test" }],
      iceTransportPolicy: "relay",
    });
    expect(hook.pushEvent).toHaveBeenCalledWith(
      "lobby_renegotiate",
      expect.objectContaining({
        recover: true,
        connection_reset: true,
        reason: "signaling_snapshot_lost",
      }),
    );
  });

  it("sends one terminal failure per recovery cycle", () => {
    const hook = buildHook();
    hook.retryCount = 99;

    hook._handleFailure();
    hook._handleFailure();
    hook.recoveryStateEventHandler(
      new CustomEvent("p2p-lobby:recovery-state", {
        detail: { state: "failed", reason: "max_retries_exhausted" },
      }),
    );

    const failedEvents = hook.pushEvent.mock.calls.filter(([event]) => event === "lobby_failed");
    expect(failedEvents).toHaveLength(1);
  });

  it("ignores stale answers from an older epoch", async () => {
    const hook = buildHook();
    hook.role = "initiator";
    hook.iceServers = [];
    await hook._createConnection();
    hook.signalingEpoch = 2;
    hook.currentOfferId = "p2p-2-1";

    await hook._handleRemoteDescription({
      type: "answer",
      sdp: "old-answer",
      epoch: 1,
      offer_id: "p2p-1-1",
    });

    expect(hook.pc.remoteDescription).toBeNull();
  });

  it("rebuilds the answerer connection for a newer connection-reset offer", async () => {
    const hook = buildHook();
    hook.role = "answerer";
    hook.iceServers = [];
    await hook._createConnection();
    const oldPc = hook.pc;

    await hook._handleRemoteDescription({
      type: "offer",
      sdp: "new-offer",
      epoch: 2,
      offer_id: "p2p-2-1",
      connection_reset: true,
    });

    expect(oldPc.connectionState).toBe("closed");
    expect(hook.signalingEpoch).toBe(2);
    expect(hook.pushEvent).toHaveBeenCalledWith(
      "lobby_signal",
      expect.objectContaining({
        type: "answer",
        sdp: expect.any(String),
        epoch: 2,
        offer_id: "p2p-2-1",
      }),
    );
  });
});
