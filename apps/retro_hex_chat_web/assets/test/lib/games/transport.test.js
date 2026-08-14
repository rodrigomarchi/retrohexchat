import { describe, it, expect, vi } from "vitest";
import {
  createDataChannelTransport,
  createLocalTransport,
  normalizeGameTransport,
} from "../../../js/lib/games/transport.js";

function createChannel() {
  return {
    readyState: "open",
    bufferedAmount: 12,
    send: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  };
}

describe("game transport", () => {
  it("wraps a DataChannel without hiding live channel state", () => {
    const channel = createChannel();
    const transport = createDataChannelTransport(channel);

    expect(transport.kind).toBe("p2p");
    expect(transport.readyState).toBe("open");
    expect(transport.bufferedAmount).toBe(12);

    channel.readyState = "closed";
    channel.bufferedAmount = 90;

    expect(transport.readyState).toBe("closed");
    expect(transport.bufferedAmount).toBe(90);
  });

  it("delegates DataChannel send and listener operations", () => {
    const channel = createChannel();
    const transport = createDataChannelTransport(channel);
    const data = new ArrayBuffer(4);
    const listener = vi.fn();

    transport.addEventListener("message", listener);
    transport.send(data);
    transport.removeEventListener("message", listener);

    expect(channel.addEventListener).toHaveBeenCalledWith("message", listener);
    expect(channel.send).toHaveBeenCalledWith(data);
    expect(channel.removeEventListener).toHaveBeenCalledWith("message", listener);
  });

  it("creates a local transport that accepts sends without network I/O", () => {
    const transport = createLocalTransport();
    const listener = vi.fn();

    transport.addEventListener("message", listener);
    expect(transport.send(new ArrayBuffer(4))).toBe(true);
    transport.removeEventListener("message", listener);

    expect(transport.kind).toBe("local");
    expect(transport.readyState).toBe("open");
    expect(transport.telemetryState).toBe("local");
    expect(transport.bufferedAmount).toBe(0);
    expect(listener).not.toHaveBeenCalled();
  });

  it("normalizes legacy channels and leaves explicit transports alone", () => {
    const channel = createChannel();
    const wrapped = normalizeGameTransport(channel);
    const explicit = createLocalTransport();

    expect(wrapped.kind).toBe("p2p");
    expect(normalizeGameTransport(explicit)).toBe(explicit);
  });
});
