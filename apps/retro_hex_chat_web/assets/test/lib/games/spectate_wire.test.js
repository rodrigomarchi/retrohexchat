import { describe, it, expect, vi } from "vitest";
import { createHostTransport, createSpectateWire } from "../../../js/lib/games/spectate_wire.js";

// A Phoenix socket double: the channel answers its join however the test says.
function fakeSocket(answer = "ok") {
  const handlers = {};
  const channel = {
    params: null,
    pushes: [],
    on: vi.fn((event, fn) => (handlers[event] = fn)),
    push: vi.fn((event, payload) => channel.pushes.push([event, payload])),
    leave: vi.fn(),
    join: () => {
      const receiver = {
        receive(status, fn) {
          if (status === answer) fn({ reason: "not_watchable" });
          return receiver;
        },
      };
      return receiver;
    },
  };

  const socket = {
    connect: vi.fn(),
    disconnect: vi.fn(),
    channel: vi.fn((topic, params) => {
      channel.topic = topic;
      channel.params = params;
      return channel;
    }),
  };

  return { socket, channel, handlers };
}

describe("spectate wire", () => {
  it("joins the session's spectate topic, as a watcher without a token", () => {
    const { socket, channel, handlers } = fakeSocket();
    const onFrame = vi.fn();
    const wire = createSpectateWire({ token: "tok", onFrame }, { createSocket: () => socket });

    wire.connect();
    expect(channel.topic).toBe("spectate:tok");
    expect(channel.params).toEqual({});

    const frame = new ArrayBuffer(2);
    handlers.frame(frame);
    handlers.frame({ not: "binary" });
    expect(onFrame).toHaveBeenCalledTimes(1);
    expect(onFrame).toHaveBeenCalledWith(frame);
  });

  it("publishes only once the server let the host in", () => {
    const refused = fakeSocket("error");
    const onRefused = vi.fn();
    const wire = createSpectateWire(
      { token: "tok", joinToken: "jt", onRefused },
      { createSocket: () => refused.socket },
    );

    wire.connect();
    wire.publish(new ArrayBuffer(1));
    expect(refused.channel.params).toEqual({ join_token: "jt" });
    expect(refused.channel.push).not.toHaveBeenCalled();
    expect(onRefused).toHaveBeenCalledWith({ reason: "not_watchable" });

    // A refusal closes the wire, so the socket stops asking again.
    expect(refused.channel.leave).toHaveBeenCalled();
    expect(refused.socket.disconnect).toHaveBeenCalled();
  });

  it("gives the host a transport that plays the match and copies it out", () => {
    const { socket, channel } = fakeSocket();
    const dataChannel = {
      readyState: "open",
      bufferedAmount: 0,
      send: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    };
    const anchor = { dataset: { sessionToken: "tok", joinToken: "jt" } };

    const host = createHostTransport(dataChannel, anchor, { createSocket: () => socket });
    const end = new Uint8Array([0x83]).buffer;
    host.transport.send(end);

    expect(dataChannel.send).toHaveBeenCalledWith(end);
    expect(channel.pushes).toEqual([["frame", end]]);

    host.destroy();
    expect(channel.leave).toHaveBeenCalled();
    expect(socket.disconnect).toHaveBeenCalled();
  });
});
