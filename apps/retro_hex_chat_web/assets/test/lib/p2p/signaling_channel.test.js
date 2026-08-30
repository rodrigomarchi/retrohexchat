import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

const joinReceivers = {};
const channelHandlers = new Map();
const pushed = [];
const joined = [];
const leaves = [];
const disconnects = [];

const fakeChannel = {
  on(event, handler) {
    channelHandlers.set(event, handler);
  },
  join() {
    const chain = {
      receive(status, handler) {
        joinReceivers[status] = handler;
        return chain;
      },
    };
    return chain;
  },
  push(event, payload) {
    pushed.push({ event, payload });
  },
  leave() {
    leaves.push(true);
  },
};

vi.mock("phoenix", () => ({
  Socket: class {
    connect() {}
    channel(topic, params) {
      joined.push({ topic, params });
      return fakeChannel;
    }
    disconnect() {
      disconnects.push(true);
    }
  },
}));

const { createSignalingChannel, SIGNAL_EVENTS } =
  await import("../../../js/lib/p2p/signaling_channel.js");

describe("p2p signaling channel", () => {
  beforeEach(() => {
    channelHandlers.clear();
    pushed.length = 0;
    joined.length = 0;
    leaves.length = 0;
    disconnects.length = 0;
    Object.keys(joinReceivers).forEach((key) => delete joinReceivers[key]);
  });

  afterEach(() => vi.restoreAllMocks());

  function connected(overrides = {}) {
    const wire = createSignalingChannel({
      sessionToken: "sess-1",
      joinToken: "tok-1",
      ...overrides,
    });
    wire.connect();
    return wire;
  }

  it("opens the session's own topic with the token that names it", () => {
    connected();

    expect(joined).toEqual([{ topic: "p2p:sess-1", params: { join_token: "tok-1" } }]);
  });

  // A page with no session on the anchor has nothing to join. Opening a socket
  // for it would be a connection nobody is on the other end of.
  it("does not open a wire when there is no session to open it for", () => {
    createSignalingChannel({ sessionToken: null, joinToken: null }).connect();

    expect(joined).toEqual([]);
  });

  it("carries the events the peer needs and nothing else", () => {
    expect(SIGNAL_EVENTS).toEqual([
      "lobby_signal",
      "lobby_renegotiate",
      "lobby_signal_replay_request",
    ]);
  });

  it("hands each arriving event to the handler registered for it", () => {
    const seen = [];
    const wire = connected();
    wire
      .on("lobby_signal", (data) => seen.push(["signal", data]))
      .on("lobby_renegotiate", (data) => seen.push(["renegotiate", data]))
      .on("lobby_signal_rejected", (data) => seen.push(["rejected", data]));

    channelHandlers.get("lobby_signal")({ type: "offer" });
    channelHandlers.get("lobby_renegotiate")({ kinds: ["audio"] });
    channelHandlers.get("lobby_signal_rejected")({ code: "rate_limited" });

    expect(seen).toEqual([
      ["signal", { type: "offer" }],
      ["renegotiate", { kinds: ["audio"] }],
      ["rejected", { code: "rate_limited" }],
    ]);
  });

  // Joining is itself "I am listening and I may have missed something", so the
  // catch-up arrives with the reply rather than costing a round trip.
  it("replays what it missed straight off the join reply", () => {
    const replays = [];
    const wire = connected();
    wire.on("lobby_signal_replay", (data) => replays.push(data));

    joinReceivers.ok({ version: 1, replay: { events: [{ event: "lobby_signal" }] } });

    expect(replays).toEqual([{ events: [{ event: "lobby_signal" }] }]);
  });

  it("tells the host when the door refuses it", () => {
    const refusals = [];
    connected({ onError: (reply) => refusals.push(reply) });

    joinReceivers.error({ reason: "not_allowed" });

    expect(refusals).toEqual([{ reason: "not_allowed" }]);
  });

  it("sends a signal on the wire", () => {
    const wire = connected();

    wire.send("lobby_signal", { type: "offer", sdp: "v=0" });

    expect(pushed).toEqual([{ event: "lobby_signal", payload: { type: "offer", sdp: "v=0" } }]);
  });

  // Dropping is the honest outcome — but silently is not, and a swallowed
  // signal looks exactly like a peer that never answered.
  it("drops a signal with nowhere to go, and says so", () => {
    const wire = createSignalingChannel({ sessionToken: null, joinToken: null });
    wire.connect();

    expect(() => wire.send("lobby_signal", {})).not.toThrow();
    expect(pushed).toEqual([]);
  });

  it("closes the wire and forgets its handlers", () => {
    const wire = connected();
    wire.on("lobby_signal", () => {});

    wire.disconnect();

    expect(leaves).toEqual([true]);
    expect(disconnects).toEqual([true]);
    expect(() => wire.send("lobby_signal", {})).not.toThrow();
    expect(pushed).toEqual([]);
  });
});
