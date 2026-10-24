/**
 * Two ends of a game DataChannel, joined in one process.
 *
 * A datagram reaches the other end on the next turn of the event loop, as a
 * real channel's does, so a handler never runs inside the `send` that caused
 * it. Every datagram is recorded with the time it was sent and its direction.
 *
 * @param {object} [options]
 * @param {(data: ArrayBuffer, dir: string) => boolean} [options.drop] - lose
 *   the datagrams it returns true for, the way an unreliable channel does.
 */
export function channelPair({ drop = () => false } = {}) {
  const wire = [];
  const host = makeEnd("host>guest");
  const guest = makeEnd("guest>host");
  host.peer = guest;
  guest.peer = host;

  function makeEnd(dir) {
    const listeners = { message: new Set(), close: new Set() };

    return {
      readyState: "open",
      bufferedAmount: 0,
      peer: null,
      listeners,

      addEventListener(type, listener) {
        listeners[type]?.add(listener);
      },

      removeEventListener(type, listener) {
        listeners[type]?.delete(listener);
      },

      send(data) {
        if (this.readyState !== "open") throw new Error("channel is not open");

        const entry = { t: Date.now(), dir, hex: hex(data) };
        const dropped = drop(data, dir);
        if (dropped) entry.dropped = true;
        wire.push(entry);
        if (dropped) return;

        const copy = data.slice(0);
        setTimeout(() => {
          if (this.peer.readyState !== "open") return;
          for (const listener of [...this.peer.listeners.message]) listener({ data: copy });
        }, 0);
      },
    };
  }

  function close() {
    for (const end of [host, guest]) {
      if (end.readyState === "closed") continue;
      end.readyState = "closed";
      for (const listener of [...end.listeners.close]) listener({ type: "close" });
    }
  }

  return { host, guest, wire, close };
}

/**
 * @param {ArrayBuffer} data
 * @returns {string}
 */
export function hex(data) {
  return [...new Uint8Array(data)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
