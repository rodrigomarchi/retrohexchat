import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { createLobbyConnection } from "../../../js/lib/p2p/lobby_connection.js";
import {
  FakeDataChannel as MockDataChannel,
  FakeRTCPeerConnection as MockRTCPeerConnection,
  sdpFor,
} from "../../helpers/rtc_peer_connection.js";

// Black-box coverage for the framework-free lobby connection controller. Every
// case drives it purely through its public surface — the server-event methods
// (handleStartOffer/handleSignal/…), the RTCPeerConnection events it wires
// (onnegotiationneeded, on*connectionstatechange, ondatachannel) and the DOM
// CustomEvents it listens for on `el` — asserting on the forwarded pushEvents,
// the FakeRTCPeerConnection state, and the CustomEvents it dispatches. No test
// reaches a private method for logic; only plain state setup is done directly.

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
      { type: "data-channel", bytesReceived: 0, bytesSent: 0, messagesReceived, messagesSent },
    ],
  ]);
}

async function flush() {
  await Promise.resolve();
  await Promise.resolve();
}

// The initiator's offer resolves through the peer connection's async
// setLocalDescription chain, and onnegotiationneeded fires it without returning
// the promise — so drain a full macrotask (real timers) to let it complete.
const macrotask = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("createLobbyConnection", () => {
  let originalRTC;
  let active;

  function makeConn() {
    const el = document.createElement("div");
    const pushed = [];
    const conn = createLobbyConnection(el, {
      pushEvent: (event, payload) => pushed.push({ event, payload }),
    });
    conn.mount();
    active = conn;
    return { conn, el, pushed };
  }

  const pushesOf = (pushed, name) => pushed.filter((p) => p.event === name).map((p) => p.payload);

  beforeEach(() => {
    active = null;
    originalRTC = globalThis.RTCPeerConnection;
    globalThis.RTCPeerConnection = MockRTCPeerConnection;
  });

  afterEach(() => {
    if (active) active.destroy();
    vi.useRealTimers();
    globalThis.RTCPeerConnection = originalRTC;
    vi.restoreAllMocks();
  });

  it("signals readiness on mount", () => {
    const { pushed } = makeConn();
    expect(pushesOf(pushed, "lobby_webrtc_ready")).toEqual([{}]);
  });

  it("creates both the filetransfer and game data channels as initiator", async () => {
    const { conn } = makeConn();

    await conn.handleStartOffer({ ice_servers: [], turn_only: false });

    expect(conn.fileChannel.label).toBe("filetransfer");
    expect(conn.gameChannel.label).toBe("gamedata");
  });

  it("hands the connection to the media hook as soon as it exists", async () => {
    const { conn, el } = makeConn();

    const ready = [];
    el.addEventListener("lobby_media_pc_ready", (event) => ready.push(event.detail.pc));

    await conn.handleStartOffer({ ice_servers: [], turn_only: false });

    // Waiting for "connected" means the first offer carries no media and the
    // media hook misses every ontrack fired while the offer was applied.
    expect(el._peerConnection).toBe(conn.pc);
    expect(ready).toEqual([conn.pc]);
  });

  it("routes an inbound gamedata channel to game_channel_ready", async () => {
    const { conn, el } = makeConn();
    await conn.handleStartAnswer({ ice_servers: [], turn_only: false });
    const channel = new MockDataChannel("gamedata", {});

    let gameReady = null;
    el.addEventListener("game_channel_ready", (e) => (gameReady = e.detail.channel));

    conn.pc.ondatachannel({ channel });
    channel.onopen();

    expect(gameReady).toBe(channel);
    expect(el._gameDataChannel).toBe(channel);
  });

  it("routes an inbound filetransfer channel to ft_channel_ready", async () => {
    const { conn, el } = makeConn();
    await conn.handleStartAnswer({ ice_servers: [], turn_only: false });
    const channel = new MockDataChannel("filetransfer", {});

    let ftReady = null;
    el.addEventListener("ft_channel_ready", (e) => (ftReady = e.detail.channel));

    conn.pc.ondatachannel({ channel });
    channel.onopen();

    expect(ftReady).toBe(channel);
    expect(el._fileTransferChannel).toBe(channel);
  });

  it("samples and pushes an always-complete per-feature lobby_stats payload", async () => {
    const { conn, el, pushed } = makeConn();
    await conn.handleStartOffer({ ice_servers: [], turn_only: false });

    conn.pc.connectionState = "connected";
    conn.pc.iceConnectionState = "connected";
    conn.signalingEpoch = 3;
    conn.currentOfferId = "p2p-3-1";
    el.dispatchEvent(
      new CustomEvent("lobby_media_source_changed", { detail: { source: "screen" } }),
    );

    // Reaching "connected" starts the always-on poller, which samples at once.
    conn.pc.onconnectionstatechange();

    await vi.waitFor(() => expect(pushesOf(pushed, "lobby_stats").length).toBeGreaterThan(0));

    expect(pushesOf(pushed, "lobby_stats").at(-1)).toEqual(
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

  it("stops the stats poller on cleanup", async () => {
    vi.useFakeTimers();
    const { conn, pushed } = makeConn();
    await conn.handleStartOffer({ ice_servers: [], turn_only: false });

    conn.pc.connectionState = "connected";
    conn.pc.iceConnectionState = "connected";
    conn.pc.onconnectionstatechange();
    await vi.advanceTimersByTimeAsync(2500);

    const sampledWhileConnected = pushesOf(pushed, "lobby_stats").length;
    expect(sampledWhileConnected).toBeGreaterThan(0);

    conn.destroy();
    await vi.advanceTimersByTimeAsync(5000);

    expect(pushesOf(pushed, "lobby_stats").length).toBe(sampledWhileConnected);
  });

  it("sends offers with epoch and offer id metadata", async () => {
    const { conn, pushed } = makeConn();
    await conn.handleStartOffer({ ice_servers: [], turn_only: false });

    conn.pc.onnegotiationneeded();
    await macrotask();

    expect(pushesOf(pushed, "lobby_signal").at(-1)).toEqual(
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
    const { conn, pushed } = makeConn();
    await conn.handleStartAnswer({ ice_servers: [], turn_only: false });

    conn.pc.connectionState = "failed";
    conn.pc.onconnectionstatechange();
    await vi.advanceTimersByTimeAsync(2000);

    expect(pushesOf(pushed, "lobby_renegotiate").at(-1)).toEqual(
      expect.objectContaining({
        recover: true,
        connection_reset: true,
        attempt: 1,
        reason: "connection_failed",
        epoch: 2,
      }),
    );
  });

  it("does not schedule overlapping automatic retries", async () => {
    vi.useFakeTimers();
    const { conn, pushed } = makeConn();
    await conn.handleStartOffer({ ice_servers: [], turn_only: false });

    conn.pc.connectionState = "failed";
    conn.pc.onconnectionstatechange();
    conn.pc.onconnectionstatechange();

    expect(pushesOf(pushed, "lobby_retry")).toHaveLength(1);
  });

  it("uses ICE failed as a recovery signal", async () => {
    vi.useFakeTimers();
    const { conn, pushed } = makeConn();
    await conn.handleStartAnswer({ ice_servers: [], turn_only: false });

    conn.pc.iceConnectionState = "failed";
    conn.pc.oniceconnectionstatechange();
    await vi.advanceTimersByTimeAsync(2000);

    expect(pushesOf(pushed, "lobby_retry")).toContainEqual({ attempt: 1, reason: "ice_failed" });
    expect(pushesOf(pushed, "lobby_renegotiate").at(-1)).toEqual(
      expect.objectContaining({ recover: true, connection_reset: true, reason: "ice_failed" }),
    );
  });

  it("requests signaling replay while startup remains unresolved", async () => {
    vi.useFakeTimers();
    const { conn, pushed } = makeConn();

    await conn.handleStartAnswer({ ice_servers: [], turn_only: false });
    pushed.length = 0;

    await vi.advanceTimersByTimeAsync(1500);

    expect(pushesOf(pushed, "lobby_signal_replay_request").at(-1)).toEqual(
      expect.objectContaining({ reason: "start_answer", attempt: 1, epoch: 1 }),
    );
  });

  it("applies signaling replay idempotently", async () => {
    vi.useFakeTimers();
    const { conn } = makeConn();
    const candidate = {
      candidate: "candidate:1 1 udp 1 127.0.0.1 9 typ host",
      sdpMid: "0",
      sdpMLineIndex: 0,
    };

    await conn.handleStartOffer({ ice_servers: [], turn_only: false });
    conn.pc.onnegotiationneeded();
    await vi.advanceTimersByTimeAsync(0);

    const setRemoteDescription = vi.spyOn(conn.pc, "setRemoteDescription");
    const addIceCandidate = vi.spyOn(conn.pc, "addIceCandidate");

    await conn.handleSignalReplay({
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
  });

  it("stands down and resyncs after the server rejects a signal as rate limited", async () => {
    vi.useFakeTimers();
    const { conn, pushed } = makeConn();

    await conn.handleStartOffer({ ice_servers: [], turn_only: false });
    conn.pc.onnegotiationneeded();
    await vi.advanceTimersByTimeAsync(0);

    pushed.length = 0;
    conn.handleSignalRejected({ code: "rate_limited", retry_after_ms: 5000 });

    // Retrying inside the window the server named only spends the window.
    vi.advanceTimersByTime(4000);
    expect(pushesOf(pushed, "lobby_signal_replay_request")).toHaveLength(0);

    vi.advanceTimersByTime(1500);
    expect(pushesOf(pushed, "lobby_signal_replay_request").at(-1)).toEqual(
      expect.objectContaining({ reason: "signal_rate_limited" }),
    );
  });

  it("retries answerer renegotiation requests until a new offer arrives", async () => {
    vi.useFakeTimers();
    const { conn, el, pushed } = makeConn();

    await conn.handleStartAnswer({ ice_servers: [], turn_only: false });
    pushed.length = 0;

    // The media watchdog's recover request drives the answerer to ask the
    // initiator for a fresh offer, which it then retries until answered.
    el.dispatchEvent(new CustomEvent("lobby_media_recover", { detail: {} }));

    expect(pushesOf(pushed, "lobby_renegotiate").at(-1)).toEqual(
      expect.objectContaining({ recover: true, reason: "media_recover" }),
    );

    await vi.advanceTimersByTimeAsync(1200);

    const renegotiates = () => pushesOf(pushed, "lobby_renegotiate");
    expect(renegotiates()).toHaveLength(2);

    await conn.handleSignal({
      type: "offer",
      sdp: "fresh-offer",
      epoch: conn.signalingEpoch,
      offer_id: "p2p-1-2",
    });

    await vi.advanceTimersByTimeAsync(4000);

    expect(renegotiates()).toHaveLength(2);
  });

  it("enters recovery when renegotiation requests are not answered", async () => {
    vi.useFakeTimers();
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const { conn, el, pushed } = makeConn();

    await conn.handleStartAnswer({ ice_servers: [], turn_only: false });
    pushed.length = 0;

    el.dispatchEvent(new CustomEvent("lobby_media_recover", { detail: {} }));
    await vi.advanceTimersByTimeAsync(1200);
    await vi.advanceTimersByTimeAsync(2400);
    await vi.advanceTimersByTimeAsync(3600);

    expect(pushesOf(pushed, "lobby_retry")).toContainEqual({
      attempt: 1,
      reason: "renegotiate_request",
    });
  });

  it("recovers after repeated ICE candidate add failures and resets on success", async () => {
    vi.useFakeTimers();
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const { conn, pushed } = makeConn();
    const candidate = (index) => ({
      candidate: `candidate:${index} 1 udp 1 127.0.0.1 ${index} typ host`,
      sdpMid: "0",
      sdpMLineIndex: 0,
    });

    await conn.handleStartAnswer({ ice_servers: [], turn_only: false });
    conn.pc.remoteDescription = { type: "offer", sdp: "remote" };
    pushed.length = 0;

    conn.pc.addIceCandidate = vi
      .fn()
      .mockRejectedValueOnce(new Error("ufrag mismatch"))
      .mockRejectedValueOnce(new Error("ufrag mismatch"))
      .mockResolvedValueOnce(undefined)
      .mockRejectedValue(new Error("ufrag mismatch"));

    const epoch = conn.signalingEpoch;
    await conn.handleSignal({ type: "ice-candidate", candidate: candidate(1), epoch });
    await conn.handleSignal({ type: "ice-candidate", candidate: candidate(2), epoch });

    expect(pushesOf(pushed, "lobby_retry")).toHaveLength(0);

    await conn.handleSignal({ type: "ice-candidate", candidate: candidate(3), epoch });
    await conn.handleSignal({ type: "ice-candidate", candidate: candidate(4), epoch });
    await conn.handleSignal({ type: "ice-candidate", candidate: candidate(5), epoch });

    expect(pushesOf(pushed, "lobby_retry")).toHaveLength(0);

    await conn.handleSignal({ type: "ice-candidate", candidate: candidate(6), epoch });

    expect(pushesOf(pushed, "lobby_retry")).toContainEqual({ attempt: 1, reason: "ice_candidate" });
  });

  it("waits through transient ICE disconnected before retrying", async () => {
    vi.useFakeTimers();
    const { conn, pushed } = makeConn();
    await conn.handleStartOffer({ ice_servers: [], turn_only: false });

    conn.pc.iceConnectionState = "disconnected";
    conn.pc.oniceconnectionstatechange();
    await vi.advanceTimersByTimeAsync(4999);

    expect(pushesOf(pushed, "lobby_recovery_pending")).toContainEqual({
      reason: "ice_disconnected",
    });
    expect(pushesOf(pushed, "lobby_retry")).toHaveLength(0);

    conn.pc.iceConnectionState = "connected";
    conn.pc.oniceconnectionstatechange();
    await vi.advanceTimersByTimeAsync(10);

    expect(pushesOf(pushed, "lobby_retry")).toHaveLength(0);
  });

  it("defers disconnected retry while getStats still shows activity", async () => {
    vi.useFakeTimers();
    const { conn, pushed } = makeConn();
    await conn.handleStartOffer({ ice_servers: [], turn_only: false });
    conn.pc.statsQueue = [
      activityStats({ bytesReceived: 100, bytesSent: 50, packetsReceived: 2, packetsSent: 1 }),
      activityStats({ bytesReceived: 200, bytesSent: 50, packetsReceived: 3, packetsSent: 1 }),
      activityStats({ bytesReceived: 200, bytesSent: 50, packetsReceived: 3, packetsSent: 1 }),
    ];

    conn.pc.iceConnectionState = "disconnected";
    conn.pc.oniceconnectionstatechange();
    await vi.advanceTimersByTimeAsync(5000);

    expect(pushesOf(pushed, "lobby_recovery_pending")).toContainEqual({
      reason: "ice_disconnected",
    });
    expect(pushesOf(pushed, "lobby_retry")).toHaveLength(0);

    await vi.advanceTimersByTimeAsync(5000);

    expect(pushesOf(pushed, "lobby_retry")).toContainEqual({
      attempt: 1,
      reason: "ice_disconnected",
    });
  });

  it("rebuilds with fresh ICE servers and relay policy from restart payload", async () => {
    const { conn, pushed } = makeConn();
    await conn.handleStartAnswer({
      ice_servers: [{ urls: "stun:old.example.test" }],
      turn_only: false,
    });
    const oldPc = conn.pc;

    await conn.handleRestart({
      ice_servers: [{ urls: "turn:relay.example.test" }],
      turn_only: true,
      reason: "signaling_snapshot_lost",
    });

    expect(oldPc.connectionState).toBe("closed");
    expect(conn.iceServers).toEqual([{ urls: "turn:relay.example.test" }]);
    expect(conn.turnOnly).toBe(true);
    expect(conn.pc.config).toEqual({
      iceServers: [{ urls: "turn:relay.example.test" }],
      iceTransportPolicy: "relay",
    });
    expect(pushesOf(pushed, "lobby_renegotiate").at(-1)).toEqual(
      expect.objectContaining({
        recover: true,
        connection_reset: true,
        reason: "signaling_snapshot_lost",
      }),
    );
  });

  it("sends one terminal failure per recovery cycle", async () => {
    const { conn, el, pushed } = makeConn();
    await conn.handleStartOffer({ ice_servers: [], turn_only: false });
    conn.retryCount = 99;

    conn.pc.connectionState = "failed";
    conn.pc.onconnectionstatechange();
    conn.pc.onconnectionstatechange();
    el.dispatchEvent(
      new CustomEvent("p2p-lobby:recovery-state", {
        detail: { state: "failed", reason: "max_retries_exhausted" },
      }),
    );

    expect(pushesOf(pushed, "lobby_failed")).toHaveLength(1);
  });

  it("ignores stale answers from an older epoch", async () => {
    const { conn } = makeConn();
    await conn.handleStartOffer({ ice_servers: [], turn_only: false });
    conn.signalingEpoch = 2;
    conn.currentOfferId = "p2p-2-1";

    await conn.handleSignal({ type: "answer", sdp: "old-answer", epoch: 1, offer_id: "p2p-1-1" });

    expect(conn.pc.remoteDescription).toBeNull();
  });

  it("rebuilds the answerer connection for a newer connection-reset offer", async () => {
    const { conn, pushed } = makeConn();
    await conn.handleStartAnswer({ ice_servers: [], turn_only: false });
    const oldPc = conn.pc;

    await conn.handleSignal({
      type: "offer",
      sdp: "new-offer",
      epoch: 2,
      offer_id: "p2p-2-1",
      connection_reset: true,
    });

    expect(oldPc.connectionState).toBe("closed");
    expect(conn.signalingEpoch).toBe(2);
    expect(pushesOf(pushed, "lobby_signal").at(-1)).toEqual(
      expect.objectContaining({
        type: "answer",
        sdp: expect.any(String),
        epoch: 2,
        offer_id: "p2p-2-1",
      }),
    );
  });
});

describe("createLobbyConnection negotiation state", () => {
  let originalRTC;
  const live = [];

  function makeConn() {
    const el = document.createElement("div");
    const pushed = [];
    const conn = createLobbyConnection(el, {
      pushEvent: (event, payload) => pushed.push({ event, payload }),
    });
    conn.mount();
    live.push(conn);
    return { conn, el, pushed };
  }

  const signalsSent = (pushed) =>
    pushed.filter((p) => p.event === "lobby_signal").map((p) => p.payload);
  const recoveryAttempts = (pushed) =>
    pushed.filter((p) => p.event === "lobby_retry").map((p) => p.payload);

  /** Bring an initiator up to a settled round: offer sent, answer applied. */
  async function settledInitiator({ kinds = ["audio", "video"] } = {}) {
    const { conn, pushed } = makeConn();
    await conn.handleStartOffer({ ice_servers: [], turn_only: false });

    for (const kind of kinds) conn.pc.addTransceiver(kind, { direction: "sendrecv" });
    conn.pc.onnegotiationneeded();
    await macrotask();

    const offer = signalsSent(pushed).at(-1);
    await conn.handleSignal({
      type: "answer",
      sdp: sdpFor(kinds),
      epoch: offer.epoch,
      offer_id: offer.offer_id,
    });
    await flush();

    return { conn, pushed, offer, kinds };
  }

  /** Bring an answerer up to a settled round: offer applied, answer sent. */
  async function settledAnswerer({ kinds = ["audio", "video"] } = {}) {
    const { conn, pushed } = makeConn();
    await conn.handleStartAnswer({ ice_servers: [], turn_only: false });

    await conn.handleSignal({ type: "offer", sdp: sdpFor(kinds), epoch: 1, offer_id: "p2p-1-1" });
    await flush();

    return { conn, pushed, kinds };
  }

  beforeEach(() => {
    live.length = 0;
    originalRTC = globalThis.RTCPeerConnection;
    globalThis.RTCPeerConnection = MockRTCPeerConnection;
  });

  afterEach(() => {
    for (const conn of live) conn.destroy();
    vi.useRealTimers();
    globalThis.RTCPeerConnection = originalRTC;
    vi.restoreAllMocks();
  });

  it("settles a clean round without recovering", async () => {
    const { conn, pushed } = await settledInitiator();

    expect(conn.pc.signalingState).toBe("stable");
    expect(recoveryAttempts(pushed)).toHaveLength(0);
  });

  it("drops an answer for a round that already settled", async () => {
    const { conn, pushed, kinds } = await settledInitiator();

    // A second answer carrying a fresh offer_id slips past the identity dedup,
    // and the connection is back in `stable` with no local offer to answer.
    await conn.handleSignal({
      type: "answer",
      sdp: sdpFor(kinds),
      epoch: conn.signalingEpoch,
      offer_id: "p2p-1-99",
    });
    await flush();

    expect(conn.pc.signalingState).toBe("stable");
    expect(recoveryAttempts(pushed)).toHaveLength(0);
  });

  it("drops a duplicate answer that arrives in the same tick as the first", async () => {
    const { conn, pushed } = makeConn();
    await conn.handleStartOffer({ ice_servers: [], turn_only: false });

    conn.pc.addTrack({ kind: "audio" });
    conn.pc.onnegotiationneeded();
    await macrotask();

    const offer = signalsSent(pushed).at(-1);
    const answer = {
      type: "answer",
      sdp: sdpFor(["audio"]),
      epoch: offer.epoch,
      offer_id: offer.offer_id,
    };

    // Both are handed over before either reaches the front of the connection's
    // operation queue, so a state check made at call time passes twice — and
    // the identity dedup has not recorded the first one yet either.
    await Promise.all([conn.handleSignal(answer), conn.handleSignal({ ...answer })]);
    await flush();

    expect(conn.pc.signalingState).toBe("stable");
    expect(recoveryAttempts(pushed)).toHaveLength(0);
  });

  it("drops an answer aimed at the peer that owns the offer", async () => {
    const { conn, pushed } = await settledAnswerer();

    // The answerer has applied a remote offer and never offers itself, so an
    // inbound answer can only be misrouted or replayed back at it.
    await conn.handleSignal({
      type: "answer",
      sdp: sdpFor(["audio", "video"]),
      epoch: conn.signalingEpoch,
      offer_id: "p2p-1-1",
    });
    await flush();

    expect(recoveryAttempts(pushed)).toHaveLength(0);
  });

  it("ignores an inbound offer while it owns the offer role", async () => {
    const { conn, pushed } = makeConn();
    await conn.handleStartOffer({ ice_servers: [], turn_only: false });

    conn.pc.addTransceiver("audio", { direction: "sendrecv" });
    conn.pc.onnegotiationneeded();
    await macrotask();

    // Single-offerer: an offer reaching the initiator is its own, echoed back.
    // Applying it moves the connection to have-remote-offer, and the real
    // answer for the outstanding offer is then unapplicable.
    await conn.handleSignal({
      type: "offer",
      sdp: sdpFor(["audio"]),
      epoch: conn.signalingEpoch,
      offer_id: "p2p-1-1",
    });
    await flush();

    expect(conn.pc.signalingState).toBe("have-local-offer");
    expect(recoveryAttempts(pushed)).toHaveLength(0);
  });

  it("does not desync when a settled description is replayed", async () => {
    const { conn, pushed, offer, kinds } = await settledInitiator();

    // Replay hands back whatever the peer last sent, without regard for the
    // state this side has since reached.
    await conn.handleSignalReplay({
      events: [
        {
          event: "lobby_signal",
          payload: {
            type: "answer",
            sdp: sdpFor(kinds),
            epoch: offer.epoch,
            offer_id: offer.offer_id,
            replay: true,
          },
        },
      ],
    });
    await flush();

    expect(conn.pc.signalingState).toBe("stable");
    expect(recoveryAttempts(pushed)).toHaveLength(0);
  });

  it("renegotiates between two peers without desyncing", async () => {
    const initiator = makeConn();
    const answerer = makeConn();

    await initiator.conn.handleStartOffer({ ice_servers: [], turn_only: false });
    await answerer.conn.handleStartAnswer({ ice_servers: [], turn_only: false });

    // Stands in for the LiveView relay, which drops a peer's own signals.
    const delivered = { initiator: 0, answerer: 0 };
    const pump = async () => {
      for (const [from, to, key] of [
        [initiator, answerer, "initiator"],
        [answerer, initiator, "answerer"],
      ]) {
        const pending = signalsSent(from.pushed).slice(delivered[key]);
        delivered[key] = signalsSent(from.pushed).length;
        for (const payload of pending) {
          await to.conn.handleSignal(payload);
          await flush();
        }
      }
    };

    initiator.conn.pc.addTrack({ kind: "audio" });
    initiator.conn.pc.onnegotiationneeded();
    await macrotask();
    await pump();
    await pump();

    expect(initiator.conn.pc.signalingState).toBe("stable");
    expect(answerer.conn.pc.signalingState).toBe("stable");

    // The answerer turns its camera on and asks for a re-offer carrying video.
    answerer.conn.pc.addTrack({ kind: "video" });
    answerer.conn.pc.onnegotiationneeded();
    const request = answerer.pushed.filter((p) => p.event === "lobby_renegotiate").at(-1).payload;
    await initiator.conn.handleRenegotiate(request);
    await macrotask();
    await pump();
    await pump();

    expect(initiator.conn.pc.signalingState).toBe("stable");
    expect(answerer.conn.pc.signalingState).toBe("stable");
    expect(initiator.conn.pc.negotiatedMLines).toEqual(answerer.conn.pc.negotiatedMLines);
    expect(recoveryAttempts(initiator.pushed)).toHaveLength(0);
    expect(recoveryAttempts(answerer.pushed)).toHaveLength(0);
  });

  it("rebuilds the connection for a connection_reset offer at the same epoch", async () => {
    const { conn, pushed } = await settledAnswerer({ kinds: ["audio", "video"] });
    const staleConnection = conn.pc;

    // The initiator rebuilt its connection and re-offered from scratch, so its
    // m-line layout no longer extends the one this side settled on. Only a
    // matching rebuild here can accept it; the epoch does not have to advance
    // for the peer's connection to be brand new.
    await conn.handleSignal({
      type: "offer",
      sdp: sdpFor(["audio"]),
      epoch: conn.signalingEpoch,
      offer_id: "p2p-1-2",
      connection_reset: true,
    });
    await flush();

    expect(conn.pc).not.toBe(staleConnection);
    expect(recoveryAttempts(pushed)).toHaveLength(0);
  });
});
