import { describe, it, expect, afterEach, beforeEach, vi } from "vitest";
import { channelPair } from "./channel_pair.js";

const bytes = (...values) => new Uint8Array(values).buffer;

describe("channel pair", () => {
  beforeEach(() => vi.useFakeTimers({ now: 0 }));
  afterEach(() => vi.useRealTimers());

  it("delivers each datagram to the other end on the next turn, in order", () => {
    const { host, guest } = channelPair();
    const received = [];
    guest.addEventListener("message", (event) => received.push([...new Uint8Array(event.data)]));

    host.send(bytes(1));
    host.send(bytes(2, 3));
    expect(received).toEqual([]);

    vi.advanceTimersByTime(0);
    expect(received).toEqual([[1], [2, 3]]);
  });

  it("records both directions with the time each datagram was sent", () => {
    const { host, guest, wire } = channelPair();
    host.send(bytes(0x80, 1));
    vi.advanceTimersByTime(16);
    guest.send(bytes(0x8e));

    expect(wire).toEqual([
      { t: 0, dir: "host>guest", hex: "8001" },
      { t: 16, dir: "guest>host", hex: "8e" },
    ]);
  });

  it("records a dropped datagram but never delivers it", () => {
    const { host, guest, wire } = channelPair({
      drop: (data, dir) => dir === "host>guest" && new Uint8Array(data)[0] === 0x84,
    });
    const received = [];
    guest.addEventListener("message", (event) => received.push(new Uint8Array(event.data)[0]));

    host.send(bytes(0x84));
    host.send(bytes(0x80));
    vi.advanceTimersByTime(0);

    expect(received).toEqual([0x80]);
    expect(wire.map((entry) => entry.dropped === true)).toEqual([true, false]);
  });

  it("closes both ends and tells both sides", () => {
    const { host, guest, close } = channelPair();
    const closed = [];
    host.addEventListener("close", () => closed.push("host"));
    guest.addEventListener("close", () => closed.push("guest"));

    close();

    expect(host.readyState).toBe("closed");
    expect(guest.readyState).toBe("closed");
    expect(closed.sort()).toEqual(["guest", "host"]);
  });

  it("stops delivering once a listener is removed", () => {
    const { host, guest } = channelPair();
    const received = [];
    const listener = () => received.push(1);
    guest.addEventListener("message", listener);
    guest.removeEventListener("message", listener);

    host.send(bytes(1));
    vi.advanceTimersByTime(0);
    expect(received).toEqual([]);
  });
});
